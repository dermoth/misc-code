/* getlog_base.h - common parameters for getlog */

/* ***** EXTERNS ***** */

/* These variables *must* be set externally */

#ifndef GETLOG_BASE
/* This is the maximum read size for each read. Optimal performance can be
 * obtained by setting this to the smallest number higher than your usual
 * line length. THIS MUST BE A 512-BYTES MULTIPLE!! I.e. 512, 1024, 8192, 8704
 * are all valid numbers.
 *
 * The current implementation limit this value to 32256 */
extern unsigned int read_chnk;

/* Maximum buffered read size (Will stop reading lines longer than this!) */
extern unsigned int max_read;

/* This has to be set to a function pointer that will handle errors in
 * various operation. The function prototype is:
 *      void handler(char *message);
 */
extern void (*getlog_err)(char *);
#endif

/* ***** DEFINES ***** */

/* This is the maximum length of error strings from strerror_r() */
#define MAX_ERRSTR 128

/* Define MALLOC_FREE if you want to free all dynamically allocated  memory.
 * Normally, the OS does a better job at is when the process exits */
/* #define MALLOC_FREE */ /* BROKEN!! */


/* ***** PROTOTYPES ***** */

/* Get first log line */
char *get_head(int);

/* Heat last log line */
char *get_tail(int);

/* Using the counter name, find index number to be used with subst_col.
 * Returns -1 is the index wasn't found */
int find_index(const char *, char *);

/* Walk a CSV-formated log line and return the value at specified position.
 * The pointer is also set to the next column, or NULL at end of line. */
char *subst_col(int, char **);

/* Compare a windows-formated timestamp with the current time */
int datediff(const char*);

/* This function convert stringe wo integers, with error checking */
int myatoi(const char*);


/* End of getlog.h */

