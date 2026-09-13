CC      = gcc
CFLAGS  = -O2 -Wall -Wextra -Wno-unused-parameter -Wno-unused-result
LDFLAGS = -lpthread

PREFIX  ?= /usr/local
BINDIR  = $(PREFIX)/bin
ETCDIR  = /etc/haram-rules

.PHONY: all clean install

all: haramd

haramd: haramd.c haramd.h
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

install: haramd
	install -d $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(ETCDIR)/blocklists
	install -m 755 haramd $(DESTDIR)$(BINDIR)/haramd
	install -m 644 config.toml $(DESTDIR)$(ETCDIR)/config.toml
	install -m 644 rules.yaml $(DESTDIR)$(ETCDIR)/rules.yaml
	install -m 644 blocklists/microsoft_domains.txt $(DESTDIR)$(ETCDIR)/blocklists/
	install -m 644 blocklists/microsoft_ips.txt $(DESTDIR)$(ETCDIR)/blocklists/

clean:
	rm -f haramd
