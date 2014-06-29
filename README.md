Staged concurrency kit for Lua

#Lstage
Lstage is a Lua library for bulding parallel, non-linear pipelines based on the concepts of the SEDA (Staged Event-Driven Architecture).

## Compiling and Installing
Lstage is compatible with Lua version 5.1

Leda requires Threading Building Blocks (TBB) to work properly.

For more information on the TBB library: http://threadingbuildingblocks.org/

To install all dependencies on a Debian like linux (Ubuntu, mint, etc) do: 

```
sudo apt-get install libtbb-dev libevent-dev lua5.1-dev lua5.1 g++
```

To clone git repository:

```
sudo apt-get install git
git clone https://github.com/brenoriba/lstage.git
```

To build Lstage:

```
make
sudo make install
```

## Installing Lstage projects

To install Image processing project:

Install dependencies:

```
sudo apt-get install aptitude
sudo aptitude install libopencv-dev libopencv-highgui-dev libimlib2-dev
sudo apt-get install lua-filesystem-dev
```

Compile:

```
make
```

Run:

```
lua run.lua
```
