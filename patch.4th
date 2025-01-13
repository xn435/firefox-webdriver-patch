include compat.4th

\ generate the machine code that will return
\ false for mozilla::dom::Navigator::Webdriver()

0 value patch-code
0 value /patch-code

here assembler
  ax ax xor
        ret
previous here
over to patch-code
swap - to /patch-code

: patch ( -- str ) patch-code /patch-code ;

: patch-file ( code-str offset-d filepath-str -- )
  r/w open-file throw >r
  r@ reposition-file throw
  r@ write-file throw
  r> close-file throw ;

variable filepath.len
512 constant /filepath
create filepath /filepath allot

: filepath! ( str -- )
  dup /filepath > abort" file path too long"
  dup filepath.len ! filepath swap move ;
: filepath@ ( -- str ) filepath filepath.len @ ;

2variable _offset
: offset@ ( -- d ) _offset 2@ ;
: offset! ( d -- ) _offset 2! ;

variable cmd.len
/filepath 128 + constant /cmd
create cmd /cmd allot

: cmd.reset ( -- )
  0 cmd.len ! ;
: >cmd ( str -- )
  dup cmd.len @ + /cmd > abort" cmd out of space"
  cmd cmd.len @ + swap dup cmd.len +! move ;
: cmd@ ( -- str ) cmd cmd.len @ ;

: cmd.build ( -- )
  cmd.reset
  s" gdb -batch " >cmd
  s" -ex 'file " >cmd filepath@ >cmd s" ' " >cmd
  s" -ex 'break Navigator::Webdriver' "     >cmd ;

: contains ( str str -- flag )
  search nip nip ;
: match ( str -- )
  2dup s" Breakpoint 1"  contains invert abort" 'Breakpoint 1' not found in gdb output"
       s" Navigator.cpp" contains invert abort" 'Navigator.cpp' not found in gdb output" ;
: extract-hex ( str -- str )
  18 /string
  2dup s" :" search invert abort" ':' not found in gdb output"
  drop nip over - ;
: (to-offset) ( str -- d )
  0 0 2swap >number 0<> abort" failed to convert offset" drop ;
: to-offset ( str -- d )
  ['] (to-offset) 16 base-execute ;
: extract ( str -- d )
  extract-hex to-offset ;
: parse-gdb ( str -- d )
  2dup match extract ;
: find-offset ( -- )
  cmd.build cmd@ sh-get parse-gdb offset! ;

: apply-patch ( -- )
  patch offset@ filepath@ patch-file ;
