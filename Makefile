#############################################
# Export external ENV variables
#############################################

include .my/.env
export

#############################################
# Common aliases
#############################################

datetime := `date +%Y-%m-%d-%H%M%S`
withLocalUser :="--user=`id -u ${USER}`:`id -g ${USER}`"

#############################################
# Docker-compose
#############################################

default:
	$(MAKE) help

## Build docker containers
build:
	docker-compose build --parallel

## Start docker containers
up:
	docker network create external || true
	docker-compose up -d --remove-orphans

## Stop docker containers
stop:
	docker-compose stop

## Restart docker containers
restart: stop up

## Remove all containers and their volumes - only in case of nothing helped
down-with-volumes:
	docker-compose down -v


#############################################
# Project
#############################################

## Init project
init: init-postgres init-mysql init-mongo init-clickhouse init-rabbit
	# Add some extra steps here: clearing cache, creating databases, executing migrations, loading fixtures, etc.

## Init PostgreSQL
init-postgres:
	docker-compose exec postgres bash -c "createdb --username=$(POSTGRES_USER) $(POSTGRES_DATABASE) || true"
	docker-compose exec postgres bash -c "createdb --username=$(POSTGRES_USER) $(POSTGRES_DATABASE_TEST)  || true"

## Init MySQL
init-mysql:
	docker-compose exec mysql bash -c "mysql --user=root --password=$(MYSQL_ROOT_PASSWORD) -e \"GRANT ALL PRIVILEGES ON *.* TO '$(MYSQL_USER)'@'%';\" || true"
	docker-compose exec mysql bash -c "mysql --user=$(MYSQL_USER) --password=$(MYSQL_PASSWORD) -e \"CREATE DATABASE IF NOT EXISTS $(MYSQL_DATABASE)\" || true"
	docker-compose exec mysql bash -c "mysql --user=$(MYSQL_USER) --password=$(MYSQL_PASSWORD) -e \"CREATE DATABASE IF NOT EXISTS $(MYSQL_DATABASE_TEST)\" || true"

## Init MongoDB
init-mongo:
	docker-compose exec mongo bash -c "mongo --username $(MONGO_USER) --password $(MONGO_PASSWORD) --verbose --eval \"db.getSiblingDB('$(MONGO_DATABASE)').createUser({user: '$(MONGO_USER)', pwd: '$(MONGO_PASSWORD)', roles: ['readWrite']})\" || true"
	docker-compose exec mongo bash -c "mongo --username $(MONGO_USER) --password $(MONGO_PASSWORD) --verbose --eval \"db.getSiblingDB('$(MONGO_DATABASE)').createCollection('init')\" || true"
	docker-compose exec mongo bash -c "mongo --username $(MONGO_USER) --password $(MONGO_PASSWORD) --verbose --eval \"db.getSiblingDB('$(MONGO_DATABASE_TEST)').createUser({user: '$(MONGO_USER)', pwd: '$(MONGO_PASSWORD)', roles: ['readWrite']})\" || true"
	docker-compose exec mongo bash -c "mongo --username $(MONGO_USER) --password $(MONGO_PASSWORD) --verbose --eval \"db.getSiblingDB('$(MONGO_DATABASE_TEST)').createCollection('init');\" || true"

## Init ClickHouse
init-clickhouse:
	docker-compose exec clickhouse bash -c "clickhouse-client --user=$(CLICKHOUSE_USER) --password=$(CLICKHOUSE_PASSWORD) --query=\"CREATE DATABASE IF NOT EXISTS $(CLICKHOUSE_DATABASE)\""
	docker-compose exec clickhouse bash -c "clickhouse-client --user=$(CLICKHOUSE_USER) --password=$(CLICKHOUSE_PASSWORD) --query=\"CREATE DATABASE IF NOT EXISTS $(CLICKHOUSE_DATABASE_TEST)\""

## Init RabbitMQ
init-rabbit:
	docker-compose exec rabbit rabbitmqctl add_vhost $(RABBIT_VHOST)
	docker-compose exec rabbit rabbitmqctl set_permissions -p $(RABBIT_VHOST) $(RABBIT_USER) ".*" ".*" ".*"

	docker-compose exec rabbit rabbitmqctl add_vhost $(RABBIT_VHOST_TEST)
	docker-compose exec rabbit rabbitmqctl set_permissions -p $(RABBIT_VHOST_TEST) $(RABBIT_USER) ".*" ".*" ".*"


#############################################
# PostgreSQL
#############################################

## Dump PostgreSQL to sql file
postgres-dump:
	docker-compose exec $(withLocalUser) postgres bash -c "pg_dump --format=custom --clean --if-exists --verbose --username=$(POSTGRES_USER) --dbname=$(POSTGRES_DATABASE) > /dump/$(datetime).dump"

## Restore PostgreSQL from restore.dump
postgres-restore:
	docker-compose exec postgres bash -c "pg_restore --clean --exit-on-error --if-exists --verbose --username=$(POSTGRES_USER) --dbname=$(POSTGRES_DATABASE) /dump/restore.dump"

#### Secondary tools: to restore from other formats

## Restore PostgreSQL from restore.sql.gz
postgres-restore-sql-gz:
	docker-compose exec postgres bash -c "PGPASSWORD=$(POSTGRES_PASSWORD) gunzip < /dump/restore.sql.gz | psql -U $(POSTGRES_USER) $(POSTGRES_DATABASE)"

## Restore PostgreSQL from restore.sql
postgres-restore-sql:
	docker-compose exec postgres bash -c "PGPASSWORD=$(POSTGRES_PASSWORD) psql -U $(POSTGRES_USER) $(POSTGRES_DATABASE) < /dump/restore.sql"


#############################################
# MySQL
#############################################

## Dump MySQL to {current-time}.sql.gz file
mysql-dump:
	docker-compose exec $(withLocalUser) mysql bash -c "mysqldump -uroot -p $(MYSQL_ROOT_PASSWORD) -v --all-databases | gzip > /dump/$(datetime).sql.gz"

## Restore MySQL from restore.sql.gz
mysql-restore:
	# rename any dump to 'restore.sql.gz' to restore it with this command
	docker-compose exec mysql bash -c "gunzip < /dump/restore.sql.gz | mysql -uroot -p $(MYSQL_ROOT_PASSWORD)"


#############################################
# MongoDB
#############################################

## Dump MongoDB to {current-time}.gz
mongo-dump:
	docker-compose exec $(withLocalUser) mongo mongodump --authenticationDatabase $(MONGO_DATABASE) --username $(MONGO_USER) --password $(MONGO_PASSWORD) --verbose --gzip --archive=/dump/$(datetime).gz

## Restore MongoDB from restore.gz
mongo-restore:
	docker-compose exec mongo mongorestore --authenticationDatabase $(MONGO_DATABASE) --username $(MONGO_USER) --password $(MONGO_PASSWORD) --drop --gzip --archive=/dump/restore.gz


#############################################
# Redis
#############################################

## Flush Redis data
redis-flush:
	docker-compose exec redis redis-cli FLUSHALL


#############################################
# Internals
#############################################

# hash for dynamic arguments. tab must be before @
%:
	@:

COLOR_RESET   = \033[0m
COLOR_INFO    = \033[32m
COLOR_COMMENT = \033[33m

help:
	printf "${COLOR_COMMENT}Usage:${COLOR_RESET}\n"
	printf " make [target] [args]\n\n"
	printf "${COLOR_COMMENT}Available targets:${COLOR_RESET}\n"
	awk '/^[a-zA-Z\-\_0-9\.@]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf " ${COLOR_INFO}%-26s${COLOR_RESET} %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)