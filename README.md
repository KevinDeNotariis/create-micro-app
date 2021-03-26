# create-micro-app - React.js / Express.js / MySQL / GraphQL / Docker

This is a powershell script which will automatically set up a **Microservices-based Web Application** with a setup taken from this wonderful video series on youtube https://www.youtube.com/watch?v=gD-WutJH0qc&ab_channel=BetterCodingAcademy with source code https://github.com/lucaschen/microservices-demo which I really recommend you to check out!

## Table of content

1. [Prerequisites](#Prerequisites)
1. [Script Usage](#script-usage)
1. [Output](#Output)
1. [Output Usage](#output-usage)

## Prerequisites

- PowerShell (https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1)

  ```ps1
  # check version
  pwsh -v
  ```

  - use `create-micro-app_v7.ps1` if you have PowerShell >= 7.0.0. This is because this script makes use of `-Parallel` in `ForEach-Object` loop, which is not present in earlier version, nor in the Windows Powershell.

  - use `create-micr-app.ps1` if you have PowerShell < 7.0.0 or just Windows Powershell.

- Yarn installed.

  ```ps1
  # check version
  yarn -v
  ```

  If you do not have it installed and you have Node.js installed (so you should have `npm`) you can:

  ```ps1
  npm install --global yarn
  ```

  Otherwise you need to install Node.js https://nodejs.org/en/

- Docker installed with the daemon running:

  ```ps1
  # check
  docker -v
  ```

  otherwise, you can install it following the instructions on the official website https://www.docker.com/get-started

## Script Usage

You can run the script in two different ways:

- Manual

  ```
  create-micro-app
  ```

  And this will prompt you with:

  ```
  Please, specify the microservices name which you would like to implement, seperated by spaces:
  ```

  And there you can put the names of the microservices that you would like to create, e.g.:

  ```
  Please, specify the microservices name which you would like to implement, seperated by spaces: chat-service users-service products-service
  ```

  And then it will ask for the name of the Web App:

  ```
  Please, specify the name of your Web App:
  ```

  You can put here the name of your web app, e.g.:

  ```
  Please, specify the name of your Web App: My-ECommerce
  ```

- Automatic, supply the arguments when running the script

  ```
  create-micro-app -a My-ECommerce -m chat-service users-service products-service
  ```

  or analogously:

  ```
  create-micro-app -app My-ECommerce -micro chat-service users-service products-service
  ```

## Output

Suppose we run the script as follows:

```
create-micro-app -a My-ECommerce -m products-service users-service
```

The script will create a `My-ECommerce` folder with inside 4 folders:

```
api-gateway
my-ecommerce
products-service
users-service
```

and a `docker-compose.yml` file.

### Microservices

The structure of each microservice is the following:

```
products-service
.
├── _node_modules
│   └── ...
├── _sequelize
│   ├── migrations
│   └── config.js
├── _src
│   ├── _db
│   │   └── connection.js
│   ├── _helpers
│   │   └── accessEnv.js
│   ├── _server
│   │   ├── routes.js
│   │   └── startServer.js
│   └─ index.js
├── _.sequelizerc
├── _babel.config.js
├── _Dockerfile
├── package.json
└── yarn.lock
```

We have a `Dockerfile` with the following content:

```dockerfile
FROM node:12

COPY . /opt/app

WORKDIR /opt/app

RUN yarn

CMD yarn watch
```

Taking then the image node:12 , copying the content of that folder into `/opt/app` inside the container and set the direction to that. Then it run `yarn` to make sure that every dependency is in place and then starts `yarn watch`.

In `sequelize` we have the folder `migrations` which should be used to create tables (and eventually roll-back) based on schemas which should be created in `/src/db` in a file named `model.js` for example.

# ... Still under development (Readme)
