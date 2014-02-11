Mad Lab lib
===========

The lastest version of the code is available at the development site:
 http://github.com/tekbasse/mad-lab-lib

Mad Laboratory Tcl and graphics library
---------------------------------------

For experimenter's working with limited or vintage computing hardware resources


license
-------
Copyright (c) 2013 Benjamin Brink
po box 20, Marylhurst, OR 97036-0020 usa
email: tekbasse@yahoo.com

Mad-Lab-lib is open source and published under the GNU General Public License

A local copy is available at LICENSE.txt

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.


features
--------

This is a library of Tcl procedures and demo for quickly building 
software tools for analyzing and reporting results of experiments.

The software requires Tcl and GraphicsMagick, both are capable 
of running on most any older 32-bit (and newer)  systems.

About Tcl: 

"Many have called it the 'best-kept secret in the software industry'. 

..easy to learn and easy to deploy!" (from: http://www.tcl.tk/about/ )

About GraphicsMagick:

"GraphicsMagick is the swiss army knife of image processing. 

..it provides a robust and efficient collection of tools and libraries 
which support reading, writing, and manipulating an image in 
over 88 major formats including important formats like 
DPX, GIF, JPEG, JPEG-2000, PNG, PDF, PNM, and TIFF."
   (from: http://www.graphicsmagick.org/ )

files
-----

mad-lab-lib.tcl    Tcl procedures
data-analyzer.tcl  A Tcl demo program that combines and summarizes data from files.
eq-data-*.txt  Filtered earthquake data used for plots, in tab-delimited format
gt-data-*.txt  Filtered global temperature data used for plots, in tab-delimited format
gt-eq-combo.txt Earthquake energy combined and appended to the global temperature data
gt-eq-trends.txt Global temperature trends with summary earthquake energy per trend.

A trend is defined as a contiguous change of temperature in the same direction.


demonstration
-------------

To run a demonstration:

0. Install Tcl ( http://tcl.tk )  and GraphicsMagick ( http://www.graphicsmagick.org ).

1. Download earthquake data greater than magnitude 6.4 from: http://www.iris.edu/ieb/ or other source.
   convert-eq.tcl expects to filter an html page saved from this source.

2. Download climate data from http://www-users.york.ac.uk/~kdc3/papers/coverage2013/methods.html or other source.
   convert-gt.tcl expects to filter a data set from this source.

3. Make changes to code to read data from files. 
   Changing the names of the data files to read in data-analyzer.tcl
   are the only modifications that should be necessary if using referenced sources as of 2013-12-13.

4. From a command shell, start the Tcl interpreter.  Type 'source data-analyzer.tcl'. 

Locally, it takes about 3 to 6 minutes to generate a chart.

