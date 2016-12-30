# docker-ocserv

## Update on December 28, 2016
You can login with two group (`Route`/`ALL`) from now on. You can also add more than one custom group
`Route` group means you can access China Mainland website directly and other connection will be protected by OpenConnect VPN
`All` group means all of connection will be protected by OpenConnect VPN 

> NOTICE: You have to use Docker version 1.9.0 or later to support Alpine, DO NOT UPDATE the image if your Docker version is older than 1.9.0



## What is OpenConnect Server?

[OpenConnect server (ocserv)](http://www.infradead.org/ocserv/) is an SSL VPN server. It implements the OpenConnect SSL VPN protocol, and has also (currently experimental) compatibility with clients using the [AnyConnect SSL VPN](http://www.cisco.com/c/en/us/support/security/anyconnect-vpn-client/tsd-products-support-series-home.html) protocol.

## How to use this image

Get the docker image by running the following commands:

```bash
docker pull benyoo/ocserv
```

Start an ocserv instance:

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -d benyoo/ocserv
```

This will start an instance with the a test user named `test` and password is also `test`.

### Environment Variables

All the variables to this image is optional, which means you don't have to type in any environment variables, and you can have a OpenConnect Server out of the box! However, if you like to config the ocserv the way you like it, here's what you wanna know.

`CA_CN`, this is the common name used to generate the CA(Certificate Authority).

`CA_ORG`, this is the organization name used to generate the CA.

`CA_DAYS`, this is the expiration days used to generate the CA.

`SRV_CN`, this is the common name used to generate the server certification.

`SRV_ORG`, this is the organization name used to generate the server certification.

`SRV_DAYS`, this is the expiration days used to generate the server certification.

`TEST_USER`, while this variable is set to not empty, the `test` user will not be created. You have to create your own user with password. The default value is to create `test` user with password `test`.

The default values of the above environment variables:

|         Variable         |      Default      |        Comment         |
| :----------------------: | :---------------: | :--------------------: |
|        **CA_CN**         |      VPN CA       | 这是用于生成CA（证书颁发机构）的公共名称。 |
|        **CA_ORG**        |     Big Corp      |     这是用于生成CA的组织名称。     |
|       **CA_DAYS**        |       9999        |     这是用于生成CA的到期天数。     |
|        **SRV_CN**        |  www.example.com  |   这是用于生成服务器认证的常用名称。    |
|       **SRV_ORG**        |    My Company     |   这是用于生成服务器认证的组织名称。    |
|       **SRV_DAYS**       |       9999        |   这是用于生成服务器认证的到期天数。    |
|   **ADD_ROUTE_GROUP**    |      disable      | 当值位enable时，可添加一个额外路由组。 |
| **ADD_ROUTE_GROUP_FILE** | /tmp/ocserv_group |       额外路由文件路径。        |
| **ADD_ROUTE_GROUP_NAME** |        DS         |       额外路由组的组名。        |
| **DEFAULTE_CONF**        | null | 当值为disable时,容器将不对配置文件做修改 |
| **OCSERV_CONF_DIR** | /etc/ocserv | 指定ocserv配置文件目录路径 |


### Running examples

Start an instance out of the box with username `test` and password `test`

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -d benyoo/ocserv
```

Start an instance with server name `my.test.com`, `My Test` and `365` days

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e SRV_CN=my.test.com -e SRV_ORG="My Test" -e SRV_DAYS=365 -d benyoo/ocserv
```

Start an instance with CA name `My CA`, `My Corp` and `3650` days

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e CA_CN="My CA" -e CA_ORG="My Corp" -e CA_DAYS=3650 -d benyoo/ocserv
```

A totally customized instance with both CA and server certification

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e CA_CN="My CA" -e CA_ORG="My Corp" -e CA_DAYS=3650 -e SRV_CN=my.test.com -e SRV_ORG="My Test" -e SRV_DAYS=365 -d benyoo/ocserv
```

Start an instance as above but without test user

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e CA_CN="My CA" -e CA_ORG="My Corp" -e CA_DAYS=3650 -e SRV_CN=my.test.com -e SRV_ORG="My Test" -e SRV_DAYS=365 -e TEST_USER=disable -v /some/path/to/ocpasswd:/etc/ocserv/ocpasswd -d benyoo/ocserv
```

Start the instance as shown above, but do not test the user and add additional routing groups.

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e CA_CN="My CA" -e CA_ORG="My Corp" -e CA_DAYS=3650 -e SRV_CN=my.test.com -e SRV_ORG="My Test" -e SRV_DAYS=365 -e TEST_USER=disable -e ADD_ROUTE_GROUP=enable -e ADD_ROUTE_GROUP_NAME=RACK -v /etc/ocserv/DS:/tmp/ocserv_group -v /some/path/to/ocpasswd:/etc/ocserv/ocpasswd -d benyoo/ocserv
```



**WARNING:** The ocserv requires the ocpasswd file to start, if `NO_TEST_USER=1` is provided, there will be no ocpasswd created, which will stop the container immediately after start it. You must specific a ocpasswd file pointed to `/etc/ocserv/ocpasswd` by using the volume argument `-v` by docker as demonstrated above.

### User operations

All the users opertaions happened while the container is running. If you used a different container name other than `ocserv`, then you have to change the container name accordingly.

#### Add user

If say, you want to create a user named `tommy`, type the following command

```bash
docker exec -ti ocserv ocpasswd -c /etc/ocserv/ocpasswd -g "Route,All" tommy
Enter password:
Re-enter password:
```

When prompt for password, type the password twice, then you will have the user with the password you want.

>`-g "Route,ALL"` means add user `tommy` to group `Route` and group `All`

#### Delete user

Delete user is similar to add user, just add another argument `-d` to the command line

```bash
docker exec -ti ocserv ocpasswd -c /etc/ocserv/ocpasswd -d test
```

The above command will delete the default user `test`, if you start the instance without using environment variable `TEST_USER`.

#### Change password

Change password is exactly the same command as add user, please refer to the command mentioned above.
