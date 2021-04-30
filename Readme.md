## Wrapper around docker-compose for common services
I built it for myself and use on projects when people do not want/can use docker for local development.
Feel free to use it in your projects without any restrictions.

**Note:** it's for local development only, not for production!

### How to use
- Copy `.my` and `Makefile` to your working project.
- Change environment variable in `.my/.env` for your needs and local project settings.
- Add `.my` and `Makefile` to .gitignore ()

### Initial one time steps
- Build images: `make build`
- Start containers: `make up`
- Wait about 10-20 seconds to be sure that all services started and ready to handle requests.
- Init project (create dev and test databases, etc): `make init`

### Everyday usage
- Start containers: `make up`
- Stop containers: `make stop`
- Restart containers: `make restart`

### Dump/restore datastores (Postgres as example)
- Dump database: `make postgres-dump`
- Go to `.my/dump/postgres` directory and rename the created file to `restore.dump`
- Restore database from `.my/dump/postgres/restore.dump`: `make postgres-restore`

### Next steps
- Look at the list of supported commands: `make help`
- Look inside `Makefile` for ideas.
- Extend `Makefile` for your own needs.