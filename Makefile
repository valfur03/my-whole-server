SERVICES = nextcloud seedbox synapse traefik web

all: c=up -d
all: $(SERVICES)

$(SERVICES) : % :
	docker-compose -f $@/docker-compose.yml $(c)

clean: c=stop
clean: $(SERVICES)

fclean: c=rm -fs
fclean: $(SERVICES)

re: c=up -d --build --force-recreate
re: $(SERVICES)

.PHONY: all clean fclean re $(SERVICES)
