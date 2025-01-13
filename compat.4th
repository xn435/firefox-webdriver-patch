\ Gforth 0.7.3 compatibility
s" gforth" environment?
[IF] s" 0.7.3" compare 0=
     [IF] \ Gforth locate1.fs:646
          User sh$  cell uallot drop
          : sh-get ( c-addr u -- c-addr2 u2 ) \ gforth
              \G Run the shell command @i{addr u}; @i{c-addr2 u2} is the output
              \G of the command.  The exit code is in @code{$?}, the output also
              \G in @code{sh$ 2@@}.
              sh$ free-mem-var
              r/o open-pipe throw dup >r slurp-fid
              r> close-pipe throw to $? 2dup sh$ 2! ;
     [THEN]
[THEN]
