all:
	g++ -Wall -shared -fPIC -o filters.so filters.c  -I/usr/include/opencv -I/usr/include/lua5.1 -I/usr/include/opencv  -lopencv_core -lopencv_imgproc -lopencv_highgui -llua5.1 
	gcc -I /usr/include/lua5.1 -I/usr/include/opencv/  -fPIC  -Wall -O2   -c -o limlib2.o limlib2.c
	gcc -o limlib2.so -shared -fPIC limlib2.o -lImlib2 -lopencv_core -lopencv_highgui -I /usr/include/lua5.1 -I/usr/include/opencv/
