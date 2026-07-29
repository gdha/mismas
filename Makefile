CC      = gcc
CFLAGS  = -std=c11 -Wall -Wextra -Wpedantic -O2
TARGETS = timeout nanosleep

.PHONY: all clean install

all: $(TARGETS)

timeout: timeout.c
	$(CC) $(CFLAGS) -o $@ $<

nanosleep: nanosleep.c
	$(CC) $(CFLAGS) -o $@ $<

install: $(TARGETS)
	install -m 0755 timeout nanosleep $(DESTDIR)/usr/local/bin/

clean:
	rm -f $(TARGETS)
