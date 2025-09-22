# Makefile for alert
CC = gcc
CFLAGS = -Wall -O2
LDFLAGS = -lcurl

TARGET = alert
SRC = alert.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(TARGET) *.o

.PHONY: all clean