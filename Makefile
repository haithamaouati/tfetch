# Build file for tfetch

VERSION ?= 1.0.0
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

CFLAGS ?= -O2
override CFLAGS += -std=gnu11 -Wall -Wextra -DTFETCH_VERSION=\"$(VERSION)\"

all: tfetch

tfetch: tfetch.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ tfetch.c

install: tfetch
	install -Dm755 tfetch $(DESTDIR)$(BINDIR)/tfetch

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/tfetch

clean:
	rm -f tfetch

.PHONY: all install uninstall clean
