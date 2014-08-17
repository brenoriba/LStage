# Lstage - Stage concurrency kit for Lua
Lstage is a Lua library for bulding parallel, non-linear pipelines based on the concepts of the SEDA (Staged Event-Driven Architecture).

# Compiling and Installing
Lstage is compatible with Lua version 5.1

Leda requires Threading Building Blocks (TBB) to work properly.

For more information on the TBB library: http://threadingbuildingblocks.org/

To install all dependencies on a Debian like linux (Ubuntu, mint, etc) do: 

```
sudo apt-get update
sudo apt-get install libtbb-dev libevent-dev libpthread-stubs0-dev lua5.1-dev lua5.1 g++ make git
```

To clone git repository:

```
git clone https://github.com/brenoriba/lstage.git
```

To build Lstage:

```
make
sudo make install
```

# Testing installation

To test if the installation was successful type this command:

```
$ lua -l lstage
```

You should get the lua prompt if lstage is installed properly or the error message "module 'lstage' not found" if it cannot be loaded 

# Installing Image Processing Project

Install dependencies:

```
sudo apt-get install aptitude lua-filesystem-dev
sudo aptitude install libopencv-dev libopencv-highgui-dev libimlib2-dev
```

Build project:

```
make
```

Run:

```
lua run.lua
```

# Installing HTTP Server Project

Build project:

```
make
```

Run server:

```
lua server.lua
```

Run client:

```
lua clients.lua
```
