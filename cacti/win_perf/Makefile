SHELL = /bin/sh

.SUFFIXES: .c .o

objects = getlog_base.o getlog.o

all: getlog

$(objects): %.o: %.c getlog.h
	$(CC) -c $(CFLAGS) $< -o $@

getlog: $(objects)
	$(CC) $(LDFLAGS) -o getlog $(objects)

.PHONY: clean
clean:
	rm -f *.o
	rm getlog

