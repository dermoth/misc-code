/*****************************************************************************
*
* Getlog base library
*
* License: GPL
* Copyright (c) 2009 Thomas Guyot-Sionnest <tguyot@gmail.com>
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
*****************************************************************************/

#define GETLOG_BASE

#include "getlog_base.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>


unsigned int read_chnk = 0;
unsigned int max_read = 0;
void (*getlog_err)(char *) = NULL;

/* Used for printing out errors strerror_r */
char errbuf[MAX_ERRSTR] = {'\0'};

/* Get the first line of the file... easy stuff */
char *get_head(int log) {
	char readbuf[read_chnk];
	int read_sz;
	char *buf = NULL;
	int buf_sz = 0;
	char *tmp = NULL;

	/* Make sure we're at the beginning */
	lseek(log, 0, SEEK_SET);

	/* Loop until we get a newline */
	while ((read_sz = read(log, readbuf, read_chnk)) > 0) {
		if ((buf = realloc(buf, buf_sz+read_sz)) == NULL)
			getlog_err("malloc failed in get_head()");

		memcpy(buf+buf_sz, readbuf, read_sz);
		buf_sz += read_sz;

		/* Terminate buf as a string if we reached end of line */
	if ((tmp = memchr(buf, '\n', buf_sz)) != NULL) {
			if (tmp[-1] == '\r') tmp--;
			tmp[0] = '\0';
			break;
		}
		if (buf_sz >= max_read) break; /* endless line? */
	}
	if (read_sz == -1) {
		strcpy(errbuf, "read: ");
		strerror_r(errno, errbuf+6, MAX_ERRSTR-6);
		getlog_err(errbuf);
	}

	/* return whatever line de got, or NULL */
	if (tmp) {
#ifdef MALLOC_FREE
		tmp = strdup(buf);
		free(buf);
		buf = tmp;
#endif
		return strdup(buf);
	}
	return NULL;
}

/* Get the last line of the file, reading backwards to make this quick on
 * large log files. */
char *get_tail(int log) {
	char readbuf[read_chnk];
	int read_sz;
	char *buf = NULL;
	int buf_sz = 0;
	char *tmp1=NULL, *tmp2=NULL;
	int c, pos=0;
	off_t length, start;
	struct stat sb;

	if (fstat(log, &sb) == -1) {
		strcpy(errbuf, "fstat: ");
		strerror_r(errno, errbuf+7, MAX_ERRSTR-7);
		getlog_err(errbuf);
	}
	length = sb.st_size; /* Size in bytes */

	/* Try to read up to read_chnk bytes at time, but make sure we read at
	 * 512-bytes boundaries. THIS IS TRICKY, don't change this unless you
	 * know what you're doing! */
	start = (length / 512) * 512;
	if (start >= read_chnk && start == length) {
		start -= read_chnk;
	} else if (start >= read_chnk) {
		start -= read_chnk - 512;
	} else {
		start = 0;
	}

	/* Set our position and start reading */
	lseek(log, start, SEEK_SET);
	while ((read_sz = read(log, readbuf, read_chnk)) > 0) {
		if ((buf = realloc(buf, buf_sz+read_sz)) == NULL)
			getlog_err("malloc failed in get_tail()");

		/* Prepend to buffer */
		if (buf_sz)
			memmove(buf+read_sz, buf, buf_sz);
		memcpy(buf, readbuf, read_sz);
		buf_sz += read_sz;

		/* Terminate buf as a string if we got a full line */
		tmp1 = tmp2 = NULL;
		pos = 0;
		while ((c=buf[pos++]) != '\0') {
			if (c == '\n') {
				tmp1 = tmp2;
				tmp2 = buf+pos-1;
			}
		}
		if (tmp1) {
			if (tmp2[-1] == '\r') tmp2--;
			tmp2[0] = '\0';
			tmp1++; /* get past first '\n' */
			break;
		}

		if (buf_sz >= max_read) break; /* endless line? */
		if ((start -= read_chnk) < 0) break;
		lseek(log, start, SEEK_SET);
	}
	if (read_sz == -1) {
		strcpy(errbuf, "read: ");
		strerror_r(errno, errbuf+6, MAX_ERRSTR-6);
		getlog_err(errbuf);
	}

	/* Return the last line if we got one */
	if (tmp1 && tmp2 && tmp2 - tmp1 > 0) {
#ifdef MALLOC_FREE
		tmp2 = strdup(tmp1);
		free(buf);
		tmp1 = tmp2;
#endif
		return strdup(tmp1);
	}
	return NULL;
}

/* Return position of index `colname` on `line`. */
int find_index(const char *colname, char *line) {
	char *col;
	int i = 0;

	while (line && (col = subst_col(0, &line)) != NULL) {
		if (strlen(col) < 3) return -1;
		/* Skip over the server name (\\name) */
		col = strchr(col+2, '\\');
		if (strcmp(col, colname) == 0) return i;
		i++;
	}
	return -1;
}

/*
 * Fetch the column indicated by colnum and remove the scanned part from
 * lineref (this allow faster scanning by find_index() ).
 * NOTE: CSV does not require delimiters on numeric values; but since Windows
 *       doesn't do that anyways it's not supported here. Could be easy to add
 *       though...
 */
char *subst_col(int colnum, char **lineref) {
	char *col=NULL;
	int i=0, pos=0, c;
	int quotestate = 0;

	/* We reached last counter on previour call, return NULL */
	if (*lineref == NULL) return NULL;

	/* First column always start here */
	if (colnum == 0) col = *lineref;

	while ((c=lineref[0][pos++]) != '\0') {
		switch (c){
			case ',':
				if (!quotestate) {
					i++;
					*lineref = *lineref + pos;
					pos = 0;
					break;
				}
			case '"':
				quotestate ^= 1;
				break;
			default:
				do {
					c = lineref[0][pos++];
				} while (c != '\0' && c != (quotestate ? '"' : ','));
				pos--;
				continue;
		}

		/* continue at field boundary */
		if (c != ',') continue;

		if (i == colnum) {
			/* found start of column */
			col = *lineref;
		} else if (col) {
			/* End of column, terminate */
			lineref[0][pos-1] = '\0';
			break;
		}
	}

	/* Not sure if this is needed, can't be too careful :) */
	if (c == '\0') *lineref = NULL;

	if (col) {
		/* We're done, remove quotes... */
		if (col[0] == '"' && col[strlen(col)-1] == '"') {
			col++;
			col[strlen(col)-1] = '\0';
		}
		return col;
	}
	return NULL;
}

/* Date string to time diff. Ex. string: "01/22/2008 07:49:19.798" */
int datediff(const char *datestr) {
	char *array[7];
	char *tmp;
	char dup[25];
	int i;
	struct tm tmstamp;

	if (strlen(datestr) != 23)
		return -1;
	strncpy(dup, datestr, 24);
	dup[23] = dup[24] = '\0';
	tmp = array[0] = dup;

	/* Loop over the string and replace separators with NULLs */
	for (i=1; i<=6; i++) {
		if ((tmp = strpbrk(tmp, "/ :.")) == NULL)
			return -1;

		tmp[0] = '\0';
		tmp++;
		array[i] = tmp;
	}

	tmstamp.tm_mon = myatoi(array[0]) - 1;
	tmstamp.tm_mday = myatoi(array[1]);
	tmstamp.tm_year = myatoi(array[2]) - 1900;
	tmstamp.tm_hour = myatoi(array[3]);
	tmstamp.tm_min = myatoi(array[4]);
	tmstamp.tm_sec = myatoi(array[5]);

	return (int)difftime (time(NULL), mktime(&tmstamp));
}

/* like atoi with error checking */
int myatoi(const char *num) {
	char *endptr;
	long val;

	errno = 0;
	val = strtol(num, &endptr, 10);

	if ((errno == ERANGE && (val == LONG_MAX || val == LONG_MIN)) || (errno != 0 && val == 0)) {
		strcpy(errbuf, "strtol: ");
		strerror_r(errno, errbuf+8, MAX_ERRSTR-8);
		getlog_err(errbuf);
	}

	if (val >= INT_MAX || val < 0)
		getlog_err("Number is of bounds");

	if (endptr == num)
		getlog_err("No digits were found");

	return (int)val;
}

