.PHONY: all
all:
	crystal build src/eyrie.cr -o bin/eyrie -p --release

.PHONY: setup
setup:
	mkdir -p /var/eyrie/cache
	mkdir -p /var/eyrie/save
	chown -R ${USER} /var/eyrie/*
	chown -R www-data:www-data /var/www/pterodactyl/*
