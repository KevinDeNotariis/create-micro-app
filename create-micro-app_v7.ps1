#########################################################
############## PARSING FLAGS AND ARGUMENTS ##############
#########################################################

function process_flag ([ref]$i, $sys_args) {
  $flag = ($sys_args[$i.value] -split '^-*')[1]
  if ($flag -eq "a" -or $flag -eq 'app') {
    $flag_content['app'] = $sys_args[$i.value + 1] 
    $i.value += 1
  } elseif ($flag -eq "m" -or $flag -eq 'micro') {
    $micro_name = [System.Collections.ArrayList]@()
    $i.value += 1
    while (!($sys_args[$i.value] -match '^-' -or $i.value -eq $sys_args.count)) {
      $micro_name.Add($sys_args[$i.value])
      $i.value += 1
    }
    $flag_content["micro"] = $micro_name
  }
}

function display_help() {
  echo "Usage: "
  echo "          create-micro-app [-a APP_NAME] [-m SERVICE1 ...]"
}

function check_duplicates($micro, $app) {
  if((compare-object ($diff2 = ( ($micro.toLower() + $app.toLower()) | select -unique)) ($micro.toLower() + $app.toLower())).count -ne 0){
    echo "Duplicate names inserted, Please Try again"
    display_help
    exit
  }
}

function check_existing_folder($folder) {
  if ($(ls).name.contains($folder.toLower())) {
    echo "Folder Already Exists"
    echo "Try again with another Name"
    exit
  }
}

$flag_content = @{}
for ($i = 0; $i -lt $args.count ; $i++ ){
  if ($args[$i] -match '^-') {
    process_flag ([ref]$i) -sys_args $args
  } else {
    echo "Error in Parsing parameters"
    display_help
    exit
  }
}

if ($flag_content.ContainsKey('app') -and $flag_content.ContainsKey(('micro'))) {
  if ($flag_content['micro'].count -ne 0) {
    check_existing_folder -folder $flag_content['app']
    # Check if the user has put two services with the same name or with the same name as the web app
    check_duplicates -micro $flag_content['micro'] -app $flag_content['app']

    mkdir $flag_content['app']
    cd $flag_content['app']
    $flag_content['app'] = $flag_content['app'].toLower() 
    mkdir $flag_content['app']
    $flag_content['micro'] | % {
      mkdir $_
    }
    $microservices = $flag_content['micro']
    $app = $flag_content['app']
  } else {
    echo "No Microservices Passed, Retry"
    display_help
    exit
  }
} else {
  if ($args.count -ne 0){
    echo "Error in Parsing Parameters or No Parameters supplied, going for manual mode"
  }

  # Ask for the user which microservices to start with
  $microservices_input = Read-Host -Prompt 'Please, specify the microservices name which you would like to implement, seperated by spaces'
  $app = Read-host -Prompt 'Please, specify the name of your Web App'
  # Check if a folder with the same name exists
  check_existing_folder -folder $app

  # Let's create the folders
  ## First, split the input
  $microservices = ($microservices_input -split '\s+').toLower()

  # Check for duplicates
  check_duplicates -micro $microservices -app $app

  ## Create a folder for each input, plus an API-gateway

  mkdir $app
  cd $app
  $app = $app.toLower()
  mkdir $app
  $microservices | % {mkdir $_}
}

mkdir api-gateway

########################################################
############## Populate the microservices ##############
########################################################

## First create an Hash_table for the ports
$ports = @{}
$microservices | % {$port_number = 7100}{
  $ports[$_] = $port_number
  $port_number++
}
## Then create the threads
$microservices | % -Parallel {
  $these_ports = $using:ports
  # Enter the microservice folder
  cd $_
  # Initialize the package.json
  $package_json = '{{
  "name": "{0}",
  "version": "1.0.0",
  "main": "index.js",
  "license": "MIT",
  "scripts": {{
    "db:migrate": "sequelize db:migrate",
    "db:migrate:undo": "sequelize db:migrate:undo",
    "watch": "babel-watch -L src/index.js"
  }}
}}' -f $_
  echo $package_json > package.json

  # Add babel-watch dev dependency
  yarn add -D babel-watch

  # Add other usefull dependencies
  yarn add @babel/core @babel/preset-env babel-plugin-module-resolver core-js regenerator-runtime cors sequelize express mysql2 sequelize-cli

  # Create the babel.config.js file
  $babel_config_js = 'module.exports = {
  plugins: [
    [
      "module-resolver",
      {
        alias: {
          "#root": "./src",
        },
      },
    ],
  ],
  presets: [
    [
      "@babel/preset-env",
      {
        targets: {
          node: "current",
        },
      },
    ],
  ],
};'
  echo $babel_config_js > babel.config.js

  # Create the /src/index.js
  mkdir src
  cd src
  $index = 'import "core-js";
import "regenerator-runtime/runtime";


import "#root/db/connection";
import "#root/server/startServer";
'  
  echo $index > index.js

  # Create the db/connection.js
  mkdir db
  cd db
  $connection = 'import { Sequelize } from "sequelize";
import accessEnv from "#root/helpers/accessEnv";

const DB_URI = accessEnv("DB_URI");

const sequelize = new Sequelize(DB_URI, {
  dialectOptions: {
    charset: "utf8",
    multipleStatements: true,
  },
  logging: false,
});

export default sequelize;
'  
  echo $connection > connection.js
  cd ..

  # Create the /helpers/accessEnv.js
  mkdir helpers
  cd helpers
  $accessEnv = 'const cache = {};
const accessEnv = (key, defaultValue) => {
  if (!(key in process.env)) {
    if (defaultValue) return defaultValue;
    throw new Error(`${key} not found in process.env!`);
  }

  if (cache[key]) return cache[key];

  cache[key] = process.env[key];

  return cache[key];
};

export default accessEnv; 
'  
  echo $accessEnv > accessEnv.js
  cd ..

  # Create the server/startServer.js
  mkdir server
  cd server
  $startServer = 'import cors from "cors";
import express from "express";

import accessEnv from "#root/helpers/accessEnv";
import setupRoutes from "./routes";
'

$startServer += '
const PORT = accessEnv("PORT", {0});
' -f $these_ports.$_

$startServer +='const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(
  cors({
    origin: (origin, cb) => cb(null, true),
    credentials: true,
  })
);

setupRoutes(app);

app.use((err, req, res, next) => {
  return res.status(500).json({
    message: err.message,
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.info(`Users service listening on ${PORT}`);
});
'  
  echo $startServer > startServer.js

  # Create the ./route
  $routes = 'const setupRoutes = (app) => {{
  app.get("/message", (req, res, next) => {{
    return res.json({{message: "This is a message from {0}"}});
  }})
}}

export default setupRoutes;
' -f $_
  echo $routes > routes.js
  cd ..
  cd ..

  # Create the Dockerfile
  $dockerfile = 'FROM node:12

COPY . /opt/app

WORKDIR /opt/app

RUN yarn

CMD yarn watch'  
  echo $dockerfile > Dockerfile

  # Create sequelize folder
  mkdir sequelize
  cd sequelize
  ## Create config
  $sequelize_config = 'module.exports.development = {
  dialect: "mysql",
  seederStorage: "sequelize",
  url: process.env.DB_URI,
};
'  
  echo $sequelize_config > config.js
  ## create migrations folder
  mkdir migrations
  cd ..

  # Create sequelizerc
  $sequelizerc = 'const path = require("path");

module.exports = {
  config: path.resolve(__dirname, "./sequelize/config.js"),
  "migrations-path": path.resolve(__dirname, "./sequelize/migrations"),
};'
  echo $sequelizerc > .sequelizerc

  cd ..
} -ThrottleLimit 10

# Let's now add the docker-compose.yml File in the root
$docker_compose = 'version: "3"
services:
  api-gateway:
    build: "./api-gateway"
    depends_on:'
$microservices | % {
  $docker_compose += '
      - {0}' -f $_
}
$docker_compose += '
    ports:
      - 7000:7000
    volumes:
      - ./api-gateway:/opt/app

'
$microservices | % {
  $docker_compose += '
  {0}:
    build: "./{0}"
    depends_on:
      - {0}-db
    environment:
      - DB_URI=mysql://root:password@{0}-db/db?charset=UTF8
    ports:
      - {1}:{1}
    volumes:
      - ./{0}:/opt/app

  {0}-db:
    environment:
      - MYSQL_ROOT_PASSWORD=password
      - MYSQL_DATABASE=db
    image: mysql:5.7.20
    ports:
    - 0.0.0.0:{2}:3306

' -f $_,$ports.$_,($ports.$_+100)

  $port_number++
  $db_port_number++
}

echo $docker_compose > docker-compose.yml


######################################################
############## Populate the API gateway ##############
######################################################

cd api-gateway
# Initialize package.json
$package_json = '{{
  "name": "{0}",
  "version": "1.0.0",
  "main": "index.js",
  "license": "MIT",
  "scripts": {{
    "db:migrate": "sequelize db:migrate",
    "db:migrate:undo": "sequelize db:migrate:undo",
    "watch": "babel-watch -L src/index.js"
  }}
}}' -f "api-gateway"
  echo $package_json > package.json

# Set up Babel
$babel_config_js = 'module.exports = {
  plugins: [
    [
      "module-resolver",
      {
        alias: {
          "#root": "./src",
        },
      },
    ],
  ],
  presets: [
    [
      "@babel/preset-env",
      {
        targets: {
          node: "current",
        },
      },
    ],
  ],
};'
echo $babel_config_js > babel.config.js

# Set up Dockerfile
$dockerfile = 'FROM node:12

COPY . /opt/app

WORKDIR /opt/app

RUN yarn

CMD yarn watch'
echo $dockerfile > Dockerfile

# Add babel-watch dev dependency
yarn add -D babel-watch

# Add other usefull dependencies
yarn add @babel/core @babel/preset-env babel-plugin-module-resolver core-js regenerator-runtime cors sequelize express cookie-parser apollo-server apollo-server-express graphql got

# Create src/index.js
mkdir src
cd src
$index = 'import "core-js";
import "regenerator-runtime/runtime";

import "#root/server/startServer";
'
echo $index > index.js
# Create server
mkdir server
cd server
## Create startServer.js
$startServer = 'import { ApolloServer } from "apollo-server-express";
import cookieParser from "cookie-parser";
import cors from "cors";
import express from "express";

import resolvers from "#root/graphql/resolvers";
import typeDefs from "#root/graphql/typeDefs";
import accessEnv from "#root/helpers/accessEnv";

const PORT = accessEnv("PORT", 7000);

const apolloServer = new ApolloServer({
  context: (a) => a,
  resolvers,
  typeDefs,
});

const app = express();

app.use(cookieParser());

app.use(
  cors({
    origin: (origin, cb) => cb(null, true),
    credentials: true,
  })
);

apolloServer.applyMiddleware({ app, cors: false, path: "/graphql" });

app.listen(PORT, "0.0.0.0", () => {
  console.info(`API gateway listening on ${PORT}`);
});'
echo $startServer > startServer.js
cd .. #src

# Create helpers/accessEnv.js
mkdir helpers
cd helpers
$accessEnv = 'const cache = {};

const accessEnv = (key, defaultValue) => {
  if (!(key in process.env)) {
    if (defaultValue) return defaultValue;
    throw new Error(`${key} not found in process.env!`);
  }

  if (cache[key]) return cache[key];

  cache[key] = process.env[key];

  return cache[key];
};

export default accessEnv;'
echo $accessEnv > accessEnv.js
cd .. #src

# Create graphql
mkdir graphql
cd graphql

# Create resolvers
mkdir resolvers
cd resolvers 
## Create index
'import * as Query from "./Query";
//import * as Mutation from "./Mutation";

const resolvers = { 
//  Mutation, 
  Query };

export default resolvers;
' > index.js

mkdir Query

## Create Mutation/index
mkdir Mutation
cd Mutation
'//export { default as <your_mutation_1> } from "./your_mutation_1>";
//export { default as <your_mutation_2> } from "./your_mutation_2>";
' > index.js
cd .. #resolvers
cd .. #graphql
cd .. #src

# Create Adapters
mkdir adapters
cd adapters
## Create camelCase names for the adapters
$microservices | % {
  $microservices_adapters_name = $_
  if (!($_ -match 'service$')) {
    $microservices_adapters_name = $_ + '-service'  
  } 
  $microservices_adapters_name_dummy = ''
  $microservices_adapters_name.split('-') | % {
    $microservices_adapters_name_dummy += $_.Substring(0,1).toUpper() + $_.Substring(1)
  }
  $microservices_adapters_name = $microservices_adapters_name_dummy

  $adapter = New-Item $microservices_adapters_name".js"
  $uri_name = ($microservices_adapters_name -split "Service")[0].toUpper() + "_SERVICE_URI"

  'import got from "got";
const {0} = "http://{1}:{2}";

export default class {3} {{
  static async example(){{
    const body = await got.get(`${{{0}}}/message`).json()
    return body;
  }}
}}
' -f $uri_name,$_,$ports[$_],$microservices_adapters_name > $adapter

  # Create Query
  cd ..
  cd graphql/resolvers
  cd Query

  ## Append to index.js
  'export {{default as {0}}} from "./{0}"' -f ($microservices_adapters_name -split "Service")[0] >> index.js

  $query = ($microservices_adapters_name -split "Service")[0] + ".js"
  ## Create <service_name>.js
  'import {0} from "#root/adapters/{0}";

const {1} = async () => {{
  return await {0}.example();
}}

export default {1}
' -f $microservices_adapters_name,(($microservices_adapters_name -split 'Service')[0] + "Resolver") > $query

  cd .. #resolvers
  cd .. #graphql
  cd .. #src
  cd adapters
}

# Create /graphql/typeDefs.js
cd .. #src
cd graphql
$typeDefs = 'import { gql } from "apollo-server";

const typeDefs = gql`
'

$microservices | % {
  $microservice_name = $_
  if ($_ -match 'service$'){
    $microservice_name = ($_ -split "service$")[0]
  }
  if ($_ -match "-") {
    $microservice_name_dummy = ''

    $microservice_name -split "-" | % {
      if($_){
        $microservice_name_dummy += $_.Substring(0,1).toUpper() + $_.Substring(1)
      }
    }
    $microservice_name = $microservice_name_dummy
  }
  $typeDefs += '  type {0}Type {{
    message: String!
  }}

' -f $microservice_name
}

$typeDefs += '  type Query{'

$microservices | % {
  $microservice_name = $_
  if ($_ -match 'service$'){
    $microservice_name = ($_ -split "service$")[0]
  }
  if ($_ -match "-") {
    $microservice_name_dummy = ''

    $microservice_name -split "-" | % {
      if($_){
        $microservice_name_dummy += $_.Substring(0,1).toUpper() + $_.Substring(1)
      }
    }
    $microservice_name = $microservice_name_dummy
  }
  $typeDefs += '
    {0}: {0}Type!' -f $microservice_name
}

$typeDefs += '
  }
`;

export default typeDefs;'

echo $typeDefs > typeDefs.js

cd .. #src
cd .. #api-gateway
cd .. #app

cd ..