#!/bin/bash

# set environmental variables
source ../../bin/setsgenvars.sh

echo Compiling findmex
echo $SGENFC findmex.f90 -o findmex.x $SGENFLAG $SGENLIB 
$SGENFC findmex.f90 -o findmex.x $SGENFLAG $SGENLIB
echo Copying executable to surfgen directory
cp findmex.x $SGENDIR 
echo Done 
