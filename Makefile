SERVICES = nextcloud synapse traefik web

include .env

all: c=up -d
all: $(SERVICES)

$(SERVICES) : % :
	DOMAIN=$(DOMAIN) docker-compose -f $@/docker-compose.yml $(c)

clean: c=stop
clean: $(SERVICES)

fclean: c=rm -fs
fclean: $(SERVICES)

re: c=up -d --build --force-recreate
re: $(SERVICES)

.PHONY: all clean fclean re $(SERVICES)
