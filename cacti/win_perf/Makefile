objects = getlog_base.o getlog.o

all: getlog

$(objects): %.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

getlog: $(objects)
	$(CC) $(LDFLAGS) -o getlog $(objects)

clean:
	rm -f *.o
	rm getlog

