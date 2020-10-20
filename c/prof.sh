gcc -mbmi2 -pg -o rev main.c
./rev
gprof rev gmon.out > prof.txt
rm gmon.out
