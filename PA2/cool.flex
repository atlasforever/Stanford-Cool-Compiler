/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
#include <string.h>
bool str_isfull();
int comment_level;
%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
ASSIGN          <-
LE              <=

SYMBOL          [\+\-\*\/\~\<\=\:\(\)\{\}\;\,\.\@]
WHITESPACE      [ \n\r\f\t\v]

COMMENT_S       \(\*
COMMENT_E       \*\)
LINE_COMMENT    --[^\n]*

INT_CONST       [0-9]+
TYPEID          [A-Z][a-zA-Z0-9_]*
OBJECTID        [a-z][a-zA-Z0-9_]*
/* Keywords */
CLASS           [cC][lL][aA][sS][sS]
ELSE            [eE][lL][sS][eE]
FI              [fF][iI]
IF              [iI][fF]
IN              [iI][nN]
INHERITS        [iI][nN][hH][eE][rR][iI][tT][sS]
LET             [lL][eE][tT]
LOOP            [lL][oO][oO][pP]
POOL            [pP][oO][oO][lL]
THEN            [tT][hH][eE][nN]
WHILE           [wW][hH][iI][lL][eE]
CASE            [cC][aA][sS][eE]
ESAC            [eE][sS][aA][cC]
OF              [oO][fF]
NEW             [nN][eE][wW]
ISVOID          [iI][sS][vV][oO][iI][dD]
TRUE            [t][rR][uU][eE]
FALSE           [f][aA][lL][sS][eE]
NOT             [nN][oO][tT]

%x STRING
%x SKIP_STRING
%x COMMENT
%%

 /*
  *  Nested comments
  */
{COMMENT_E} {
    cool_yylval.error_msg = "Unmatched *)";
    return (ERROR);
}
{LINE_COMMENT} {}
{COMMENT_S} {
    BEGIN COMMENT;
    comment_level = 1;
}
<COMMENT>{
    <<EOF>> {
        cool_yylval.error_msg = "EOF in comment";
        BEGIN INITIAL;
        return (ERROR);
    }
    {COMMENT_S} {
        comment_level++;
    }
    \n {
        curr_lineno++;
    }
    . {}
    {COMMENT_E} {
        comment_level--;
        if (comment_level == 0) {
            BEGIN INITIAL;
        }
    }
}
 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
{ASSIGN}        { return (ASSIGN); }
{LE}            { return (LE); }

 /* Single character symbols */
{SYMBOL} { return int(yytext[0]); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
{CLASS}         { return (CLASS); }
{ELSE}          { return (ELSE); }
{FI}            { return (FI); }
{IF}            { return (IF); }
{IN}            { return (IN); }
{INHERITS}      { return (INHERITS); }
{LET}           { return (LET); }
{LOOP}          { return (LOOP); }
{POOL}          { return (POOL); }
{THEN}          { return (THEN); }
{WHILE}         { return (WHILE); }
{CASE}          { return (CASE); }
{ESAC}          { return (ESAC); }
{OF}            { return (OF); }
{NEW}           { return (NEW); }
{ISVOID}        { return (ISVOID); }
{NOT}           { return (NOT); }
 /* Const things */
{INT_CONST} {
    cool_yylval.symbol = inttable.add_string(yytext);
    return (INT_CONST);
}
{TRUE} {
    cool_yylval.boolean = true;
    return (BOOL_CONST);
}
{FALSE} {
    cool_yylval.boolean = false;
    return (BOOL_CONST);
}

 /* Identifiers */
{TYPEID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return (TYPEID);
}
{OBJECTID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return (OBJECTID);
}

 /* Whitespace */
{WHITESPACE} {
    if (yytext[0] == '\n') {
        curr_lineno++;
    }
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
\" {
    strcpy(string_buf, "");
    BEGIN STRING;
}
<STRING>\\\0 {
    cool_yylval.error_msg = "String contains null character";
    BEGIN SKIP_STRING;
    return (ERROR);
}
<STRING>\\(.|\n) {
    if (!str_isfull()) {
        switch (yytext[1]) {
        case 'n':
            strcat(string_buf, "\n");
            break;
        case 't':
            strcat(string_buf, "\t");
            break;
        case 'b':
            strcat(string_buf, "\b");
            break;
        case 'f':
            strcat(string_buf, "\f");
            break;
        default:    // '\''\n' or '\''0' is allowed
            strcat(string_buf, yytext + 1);
            if (yytext[1] == '\n') {
                curr_lineno++;
            } 
            break;
        }
    } else {
        cool_yylval.error_msg = "String constant too long";
        BEGIN SKIP_STRING;
        return (ERROR);
    }
}
<STRING><<EOF>> {
    cool_yylval.error_msg = "EOF in string constant";
    BEGIN INITIAL;
    return (ERROR);
}
<STRING>\n {
    curr_lineno++;
    cool_yylval.error_msg = "Unterminated string constant";
    BEGIN INITIAL;
    return (ERROR);
}
<STRING>\0 {
    cool_yylval.error_msg = "String contains null character";
    BEGIN SKIP_STRING;
    return (ERROR);
}
<STRING>\" {
    cool_yylval.symbol = stringtable.add_string(string_buf);
    BEGIN INITIAL;
    return (STR_CONST);
        
}
<STRING>. {
    if (!str_isfull()) {
        strcat(string_buf, yytext);
    } else {
        cool_yylval.error_msg = "String constant too long";
        BEGIN SKIP_STRING;
        return (ERROR);
    }
}

<SKIP_STRING>\\\n {
    curr_lineno++;
}
<SKIP_STRING>\n {
    curr_lineno++;
    BEGIN INITIAL;
}
<SKIP_STRING>\" {
    BEGIN INITIAL;
}
<SKIP_STRING>. {}    



 /* Invalid characters */
. {
    cool_yylval.error_msg = yytext;
    return (ERROR);
}
%%

bool str_isfull()
{
    if (strlen(string_buf) + 1 >= MAX_STR_CONST) {
        return true;
    } else {
        return false;
    }
}

