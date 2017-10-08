#  mad-lab-lib.tcl

#  Mad Laboratory Tcl and graphics library
#  For experimenter's with limited computing hardware resources

#  License
#  Copyright (c) 2013 Benjamin Brink
#  Marylhurst, Oregon, usa
#  email: tekbasse@yahoo.com

#  Some parts licensed under separate, compatible licenses.
#  Mad-Lab-lib is open source and published under the GNU General Public License

#  A local copy is available at LICENSE.txt




if { [catch {package require TclMagick} err_msg ] } {
    #puts "TclMagick not available. Using graphicsmagick directly."
    set __TclMagick_p 0
} else {
    #puts "Using TclMagick (This feature not implemented)."
    set __TclMagick_p 1
}

puts "sourcing mad-lab-lib.tcl"
set tcl_version [info tclversion]
puts "Tcl version [info patchlevel]"
if { $tcl_version < 8.5 } {
    # Report TCL environment (version). 
    puts "Tcl version 8.5 or above recommended for math processing."
}

proc mll_gm_path_builder { list_of_points } {
    # Convert a list of x_y coordinates to gm -draw path's paramter format.
    set point_count [expr { [llength $list_of_points] / 2 } ]
    set x [lindex $list_of_points 0]
    set y [lindex $list_of_points 1]
    if { $point_count > 1 } {
        # Move to first point, then draw to each that follows.
        # This code errors when single quotes wrap path_specification
        # and infrequently when there isn't any. :-/
        # Apparently, assigning colors to new variables causes problems if the # is not quoted like \#
        set path_specification "path '"
        set movement_type "M"
        append path_specification "${movement_type} $x $y"
        set movement_type " L"
        foreach {x y} $list_of_points {
            append path_specification "${movement_type} $x $y"
        }
        append path_specification "'"
    } else {
        # path is a point
        set path_specification "point $x,$y"
    }
    return $path_specification
}

proc mll_image_width_height { filename } {
    # returns the width and height in pixels of filename as a list: width, height.
    # original from OpenACS photo-album pa_image_width_height
    set identify_string [exec gm identify $filename]
    regexp {[ ]+([0-9]+)[x]([0-9]+)[\+]*} $identify_string x width height
    return [list $width $height]
}


proc mll_draw_image_path_color { imagename x_y_coordinates_list color {opacity 1} } {
    # Draw a path of line segments.
    # Move to first x_y_coordinate in path represented as a list
    # then draw to each coordinate thereafter.
    # gm usage ref: graphicsmagick.org/wand/drawing_wand.html#drawsetstrokeopacity
    #          and: graphicsmagick.org/1.2/www/GraphicsMagick.html
    # gm comvert infile -operator opacity xor "100%" outfile
    # gm convert infile -operator opacity xor|add|and|or|subtract "60%" outfile
    set fillcolor "none"
    while { [llength $x_y_coordinates_list] > 100 } {
        set path_segment [lrange $x_y_coordinates_list 0 99]
        set x_y_coordinates_list [lrange $x_y_coordinates_list 98 end]
        #puts "exec gm convert -fill none -stroke $color -draw [gm_path_builder $path_segment ] $imagename $imagename"
        exec gm convert -fill $fillcolor -stroke $color -draw [mll_gm_path_builder $path_segment ] $imagename $imagename
    }
    # This works in bash shell:
    # gm convert gt-eq-plot-0-0.png -fill "#0000ff" -stroke "#0000ff" -draw 'path "M 50 55 L 60 65 L 70 75" circle 80,85 90,95 point 100,105' gt-eq-plot-0-0.png


    #puts "exec gm convert -fill none -stroke $color -draw [mll_gm_path_builder $x_y_coordinates_list ] $imagename $imagename"
    set path [mll_gm_path_builder $x_y_coordinates_list ]
    if { [string match "*point*" $path] } {
        #set fillcolor $color
        #puts "exec gm convert $imagename -fill $color -draw $path $imagename"
        exec gm convert $imagename -fill $color -draw $path $imagename
    } else {
        exec gm convert $imagename -fill $fillcolor -stroke $color -draw $path $imagename
    }
}

proc mll_draw_image_rect_color { imagename x0 y0 x1 y1 fillcolor {bordercolor ""} {opacity 1} } {
    # Draw a rectangle
    if { $bordercolor eq ""} {
        set bordercolor $fillcolor
        set strokewidth 0
    } else {
        set strokewidth 1
    }
    if { $x0 == $x1 && $y0 == $y1 } {
        # make this point larger.. so we can see it.
        if { $x0 < $x1 } {
            incr x0 -1
            incr y0 -1
            incr x1 1
            incr y1 1
        } else {
            incr x0 1
            incr y0 1
            incr x1 -1
            incr y1 -1
        }            
    }
    exec gm convert -fill $fillcolor -stroke $bordercolor -draw "rectangle $x0,$y0 $x1,$y1" $imagename $imagename
}

proc mll_annotate_image_pos_color { imagename x y color text } {
    # Annotate an image
    # To annotate with blue text using font 12x24 at position (100,100), use:
    #    gm convert -font helvetica -fill blue -draw "text 100,100 Cockatoo" bird.jpg bird.miff
    # from: http://www.graphicsmagick.org/convert.html
    # Do not specify font for now. For compatibility between systems, assume there is a gm default.
    # exec gm convert -font "courier new" -fill $color -draw "text $x,$y $text" $imagename $imagename
    exec gm convert -fill $color -draw "text $x,$y '$text'" $imagename $imagename
}

proc mll_scale { x } {
    # energy of 6.4 mag eq = k, where energy = \[expr { pow( 10. , 1.5 * $mag + 16.1) * $eq_unit_conv_factor } \]
    # k = 5.011872336272756 @ mag = 6.4
    # k = 3.548133892335761 @ mag = 6.3
    # Using magnitude 6.3 for scaling, because 6.4 is error range for 6.5 earthquakes (a data boundary value)
    set k 3.548133892335761
    if { $x < $k } {
        #set x2 [expr { log10( $k ) } ]
        # .. is a constant:
        set x2 0.5500000000000007
    } else {
        set x2 [expr { log10( $x ) } ]
    }
    return $x2
}

proc mll_list_of_lists_to_file { filename list_of_lists } {
    set fileId [open $filename w]
    foreach row $list_of_lists {
        puts $fileId [join $row \t]
    }
    close $fileId
}

proc mll_pretty_metric { number {unit ""} {significand "1"} {ignore_units ""} } {
    set number_abs [expr { abs( $number ) } ]

    # ref: http://en.wikipedia.org/wiki/Metric_prefix#List_of_SI_prefixes
    # The yy yyy yyyy and YY YYY YYYY extensions are nonstandard for SI, but may be useful in some graphs nevertheless.
    set abbrev_list [list yyyy gglmn yyy yy y z a f p n "&mu;" m c d "" da h k M G T P E Z Y YY YYY Ggl YYYY]
    set prefix_list [list quadyocto googolmin triyocto duoyocto yocto zepto atto femto pico nano micro milli centi deci "" deca hecto kilo mega giga tera peta exa zetta yotta duoyotta triyotta googol quadyotta]
    set ab_pow_list [list -192 -100 -96 -48 -24 -21 -18 -15 -12 -9 -6 -3 -2 -1 0 1 2 3 6 9 12 15 18 21 24 48 96 100 192]
    # sometimes &mu; is replaced with mcg..
    # remove units to ignore
    if { [string length $ignore_units] > 0 } {
        set ignore_list [split $ignore_units ", "]
        foreach i $ignore_list {
            set ii [lsearch -exact $abbrev_list $i]
            if { $ii > -1 } {
                set abbrev_list [lreplace $abbrev_list $ii $ii]
                set ab_pow_list [lreplace $ab_pow_list $ii $ii]
            }
        }
    } 
    # convert number to base of one unit (if unit is other than one).
    set unit_index [lsearch -exact $abbrev_list $unit]
    if { $unit_index > -1 } {
        set number [expr { $number * pow(10,[lindex $ab_pow_list $unit_index]) } ]
        set number_abs [expr { abs( $number ) } ]
        set unit ""
    }
    #    set units_list \[list pico nano micro milli centi deci "" deca hecto kilo mega giga tera \]
    set test_base_nbr 1e[lindex $ab_pow_list 0]
    set i 0
    foreach abbrev $abbrev_list {
        if { $number_abs > $test_base_nbr } {
            set base_nbr $test_base_nbr
            set unit $abbrev
            incr i
            set test_base_nbr [expr { pow(10,[lindex $ab_pow_list $i]) } ] 
#            puts "testing unit $unit base_nbr $base_nbr test_base_nbr $test_base_nbr i $i"
        } 

    }
    if { [info exists base_nbr] } {
        set base_metric [expr { $number / ( $base_nbr * 1. ) } ]
        if { $significand > 1 } {
            set extra_significand [expr { $significand - 1 } ]
            set metric [format "%+3.${extra_significand}f" $base_metric]
        } else {
            set metric [format "%+3d" [expr { round( $base_metric ) } ]]
        }
        set pretty_metric "${metric} ${unit}"
    } else {
        # out of range
        set pretty_metric [format "%+3.${significand}g" $number]
    }
    return $pretty_metric
}

proc mll_graph_lol { {type "lin-lin"} filename region data_list_of_lists x_index y_index x_style y_style x_ticks_count y_ticks_count x_title y_title } {
    upvar $data_list_of_lists data_lists
    # if x_index or y_index is a list: 
    # 1 element in list: index
    # 2 elements in list: index, error (index value +/- this value)
    # 3 elements in list: index, low_error, high_error
    
    set time_start [clock seconds]
    # type: lin-lin lin-log log-lin log-log
    # filename: if doesn't exist, is created
    # region is box in filename defined by X1,Y1xX2,Y2 separated by commas or x thereby converted to list of 4 numbers
    # index is index number of list in lists of lists
    # style is of type bars (chart1), scatterplot (chart3), trendblock(chart2)

    # ..............................................................
    # Graph results.
    if { $filename eq "" } {
        set timestamp [clock format [clock seconds] -format "%Y%m%dT%H%M%S"]
        set filename "~/${timestamp}.png"
    }
    # Extract data and statistics 
    # ordered elements
    set xo_list [list ]
    set yo_list [list ]
    set pxy_lists [list ]
    set pxxm_lists [list ]
    set pyym_lists [list ]
    # Determine x_index_type and y_index_type
    if { [llength $x_index] > 1 } {
        set x3_index [lindex $x_index 2]
        set x2_index [lindex $x_index 1]
        set x1_index [lindex $x_index 0]
    } else {
        set x1_index $x_index
    }
    if { [info exists x3_index] } {
        if { $x3_index ne "" } {
            # separate full value ranges for x value high and low
            set x_index_type 3
        } elseif { $x2_index ne "" } {
            # use a single relative value for calculating x error (+/-)
            set x_index_type 2
        }
    } else {
        set x_index_type 1
    }
    if { [llength $y_index] > 1 } {
        set y3_index [lindex $y_index 2]
        set y2_index [lindex $y_index 1]
        set y1_index [lindex $y_index 0]
    } else {
        set y1_index $y_index
    }
    if { [info exists y3_index] } {
        if { $y3_index ne "" } {
            # separate full value ranges for y value high and low
            set y_index_type 3
        } elseif { $y2_index ne "" } {
            # use a single relative value for calculating x error (+/-)
            set y_index_type 2
        }
    } else {
        set y_index_type 1
    }
    # Extract and prepare datapoints from data_list_of_lists
    set ximin ""
    set ximax ""
    set yimin ""
    set yimax ""
    set first_dp_list [lindex $data_lists 0] 
    set x1_index_ck [regexp {[^0-9]+} [lindex $first_dp_list $x1_index] scratch]
    set x2_index_ck [regexp {[^0-9]+} [lindex $first_dp_list $x2_index] scratch]
    if { $x1_index_ck || $y1_index_ck } {
        # drop first row as a title row
        set di 1
    } else {
        set di 0
    }
    foreach dp_list [lrange $data_lists $di end] {
        set xi [lindex $dp_list $x1_index]
        lappend xo_list $xi
        switch -exact $x_index_type {
            2 {
                set xii [lindex $dp_list $x2_index]
                set ximin [expr { $xi - $xii } ]
                set ximax [expr { $xi + $xii } ]
                lappend xomin_list $ximin
                lappend xomax_list $ximax
            }
            3 {
                set ximin [lindex $dp_list $x2_index]
                set ximax [lindex $dp_list $x3_index]
                lappend xomin_list $ximin
                lappend xomax_list $ximax
            }
        }
        set pxx [list $ximin $ximax]
        lappend pxxm_lists $pxx
        set yi [lindex $dp_list $y1_index]
        lappend yo_list $yi
        switch -exact $y_index_type {
            2 {
                set yii [lindex $dp_list $y2_index]
                set yimin [expr { $yi - $yii } ]
                set yimax [expr { $yi + $yii } ]
                lappend yomin_list $yimin
                lappend yomax_list $yimax
            }
            3 {
                set yimin [lindex $dp_list $y2_index]
                set yimax [lindex $dp_list $y3_index]
                lappend yomin_list $yimin
                lappend yomax_list $yimax
            }
        }
        set pyy [list $yimin $yimax]
        lappend pyym_lists $pyy

        set pxy [list $xi $yi]
        lappend pxy_lists $pxy
    }

    set pcount [llength $pxy_lists]
    set x_graph_type [string range $type 0 2]
    set y_graph_type [string range $type 4 6]

    set xox_list [lsort -real $xo_list]
    set fx_min [lindex $xox_list 0]
    set fx_max [lindex $xox_list end]
 
    if { $x_index_type > 1 } {
        # determin max and mins from calculated min and calculated max
        set xoxmin_list [lsort -real $xomin_list]
        set fx2_min [lindex $xoxmin_list 0]
        set xoxmax_list [lsort -real $xomax_list]
        set fx2_max [lindex $xoxmax_list end]
        if { $fx2_min < $fx_min } {
            set fx_min $fx2_min
        } else {
            puts "mll_graph_lol(324): Why isn't fx2_min $fx2_min less than fx_min $fx_min ?"
        }
        if { $fx2_max > $fx_max } {
            set fx_max $fx2_max
        } else {
            puts "mll_graph_lol(327): Why isn't fx2_max $fx2_max greater than fx_max $fx_max ?"
        }
    }

    set yox_list [lsort -real $yo_list]
    set fy_min [lindex $yox_list 0]
    set fy_max [lindex $yox_list end]
    if { $y_index_type > 1 } {
        # determin max and mins from calculated min and calculated max
        set yoxmin_list [lsort -real $yomin_list]
        set fy2_min [lindex $yoxmin_list 0]
        set yoxmax_list [lsort -real $yomax_list]
        set fy2_max [lindex $yoxmax_list end]
        if { $fy2_min < $fy_min } {
            set fy_min $fy2_min
        } else {
            puts "mll_graph_lol(343): Why isn't fy2_min $fy2_min less than fy_min $fy_min ?"
        }
        if { $fy2_max > $fy_max } {
            set fy_max $fy2_max
        } else {
            puts "mll_graph_lol(348): Why isn't fy2_max $fy2_max greater than fy_max $fy_max ?"
        }
    }

    set fx_range [expr { $fx_max - $fx_min } ]
    set fy_range [expr { $fy_max - $fy_min } ]
#puts "fx_min $fx_min fx_max $fx_max fx_range $fx_range fy_min $fy_min fy_max $fy_max fy_range $fy_range"
    # Determine plot region
    set region_list [split $region ",: x"]    
    if { [llength $region_list] == 4 } {
        if { [lindex $region_list 0] < [lindex $region_list 2] } {
            set x1 [lindex $region_list 0]
            set y1 [lindex $region_list 1]
            set x2 [lindex $region_list 2]
            set y2 [lindex $region_list 3]
        } else {
            set x2 [lindex $region_list 0]
            set y2 [lindex $region_list 1]
            set x1 [lindex $region_list 2]
            set y1 [lindex $region_list 3]
        }
        if { $y2 < $y1 } {
            set y $y1
            set y1 $y2
            set y2 $y
        }
    } else {
        # create a plot region
        set margin 70
        set x1 $margin
        set y1 $margin
        if { [llength $region_list] > 0 } {
            # work with available inputs
            set region_list [lsort -real $region_list]
            set x2 [lindex $region_list end] 
            set y2 $x2
        } else {
            # about a standard page size
            set x2 [expr { round( int( 1000. / $pcount ) * $pcount + ( $margin ) ) } ]
            set y2 [expr { round( int( 1400. / $pcount ) * $pcount + ( $margin ) ) } ]
        }
    }

    if { ![file exists $filename] } {
        # Create canvas image
        # to create a solid red canvas image:
        # gm convert -size 640x480 "xc:#f00" canvas.png
        # from: www.graphicsmagick.org/FAQ.html

        # Assume the same border for the farsides. It may be easier for a user to clip than to add margin.
        set width_px [expr { $x2 + 2 * $x1 } ]
        set height_px [expr { $y2 + 2 * $y1 } ]
        puts "Creating ${width_px}x${height_px} image: $filename"
        exec gm convert -size ${width_px}x${height_px} "xc:#ffffff" $filename
    }

    # ..............................................................
    # Determine charting constants
    set x_delta [expr { $x2 - $x1 } ]
    set y_delta [expr { $y2 - $y1 } ]
    
    # statistics of data for plot transformations
    # fx_min, fx_max, fx_range
    # fy_min, fy_max, fy_range
    
    # ..............................................................
    # Create chart grid
    if { $x_ticks_count > -1 } {
        incr x_ticks_count -1
    }
    if { $y_ticks_count > -1 } {
        incr y_ticks_count -1
    }

    # Add an x or y origin line?
    if {  [string match "*origin*" $x_style] } {
        set x_0 [expr { round( $x1 + $x_delta * ( 0 - $fx_min ) / $fx_range ) } ]
        mll_draw_image_path_color $filename [list $x_0 $y1 $x_0 $y2] "#eeeeee"
    }
    if { [string match "*origin*" $y_style] } {
        set y_0 [expr { round( $y2 - $y_delta * ( 0 - $fy_min ) / $fy_range ) } ]
        mll_draw_image_path_color $filename [list $x1 $y_0 $x2 $y_0] "#eeeeee"
    }


    # x axis
    mll_draw_image_path_color $filename [list $x1 $y2 $x2 $y2] "#ccccff"
    # x axis ticks
    set y_tick [expr { $y2 + 4 } ]
    set k1 [expr { $x_delta / ( $x_ticks_count * 1. ) } ]
    for {set i 0} {$i <= $x_ticks_count } {incr i} {
        set x_plot [expr { round( $x1 + $k1 * ( $i * 1. ) ) } ]
        mll_draw_image_path_color $filename [list $x_plot $y2 $x_plot $y_tick] "#ccccff"
    }
    if { ![info exists width_px ] } {
        set width_px [lindex [mll_image_width_height $filename] 0]
    }
    # Rotate image, plot values for x-axis ticks
    exec gm convert -rotate 270 $filename $filename
    # swap x and y coordinates, since rotated by 90 degrees.
    set y_tick [expr { $y2 + 6 } ]
    set k2 [expr { $fx_range / ( $x_ticks_count * 1. ) } ]
    set x2_margin [expr { $width_px - $x2 } ]
    for {set i 0} {$i <= $x_ticks_count } {incr i} {
        set x_plot [expr { round( $x2_margin + ( $i * 1. ) * $k1 ) } ]
        set x [expr { $fx_max - $k2 * ( $i * 1. ) } ]
        mll_annotate_image_pos_color $filename $y_tick $x_plot "#aaaaff" [mll_pretty_metric $x "" 2 "c d da h"]
    }
    # rotate back.
    exec gm convert -rotate 90 $filename $filename

    # y axis, left side
    mll_draw_image_path_color $filename [list $x1 $y1 $x1 $y2] "#ffaaaa"
    # y axis ticks
    set x_tick [expr { $x1 - 40 } ]
    if { $x_tick < 0 } {
        set x_tick 1
    }
    set k1 [expr { $y_delta / ( 1. * $y_ticks_count ) } ]
    set k2 [expr { $fy_range / ( $y_ticks_count * 1. ) } ]
    for {set i 0} {$i <= $y_ticks_count } {incr i} {
        set y_plot [expr { round( $y2 - $k1 * $i ) } ] 
        mll_draw_image_path_color $filename [list $x1 $y_plot $x_tick $y_plot] "#ffaaaa"
        # add label
        set y_tick [expr { $y_plot - 6 } ]
        set y [expr { $k2 * ( $i * 1. ) + $fy_min } ]
        mll_annotate_image_pos_color $filename $x_tick $y_tick "#ffaaaa" "[mll_pretty_metric $y "" 2 "c d da h"]"
    }


    # ..............................................................
    # background 
    set i 0
    foreach p_x_y $pxy_lists {
        if { $x_index_type > 1 } {
            set yval [lindex $p_x_y 1]            
            set y [expr { round( $y2 - $y_delta * ( $yval - $fy_min ) / $fy_range ) } ] 
            set pxx [lindex $pxxm_lists $i] 
            set x_min [lindex $pxx 0]
            set x_max [lindex $pxx 1]
            set x [lindex $p_x_y 0]
            if { $x_min < $x && $x < $x_max } {
                # plot x min to max @ y
                set x_min [expr { round( $x1 + $x_delta * ( $x_min - $fx_min ) / $fx_range ) } ]
                set x_max [expr { round( $x1 + $x_delta * ( $x_max - $fx_min ) / $fx_range ) } ]
                mll_draw_image_path_color $filename [list $x_min $y $x_max $y] "#99ccff"
            } else {
                puts "Warning: x_min $x_min < x $x < x_max $x_max"
            }
        }
        if { $y_index_type > 1 } {
            set xval [lindex $p_x_y 0]
            set x [expr { round( $x1 + $x_delta * ( $xval - $fx_min ) / $fx_range ) } ]
            set pyy [lindex $pyym_lists $i] 
            set y_min [lindex $pyy 0]
            set y_max [lindex $pyy 1]
            set y_min [expr { round( $y2 - $y_delta * ( $y_min - $fy_min ) / $fy_range ) } ] 
            set y_max [expr { round( $y2 - $y_delta * ( $y_max - $fy_min ) / $fy_range ) } ] 
            # plot y min to max @ x
            mll_draw_image_path_color $filename [list $x $y_min $x $y_max] "#ffcc99"
        }
        incr i
    }

    # Titles
    set y_plot [expr  { $y1 - 20 } ]
    if { $y_plot < 0 } {
        set y_plot 1
    }
    mll_annotate_image_pos_color $filename [expr { round( ( $x1 + $x2 - [string length $y_title] * 12 ) / 2. ) } ] [expr { $y_plot } ] "#ff0000" $y_title
    mll_annotate_image_pos_color $filename [expr { round( ( $x1 + $x2 - [string length $x_title] * 12 ) / 2. ) } ] [expr { $y_plot + 20 } ] "#0000ff" $x_title

    # foreground
    foreach p_x_y $pxy_lists {
        set xval [lindex $p_x_y 0]
        set yval [lindex $p_x_y 1]
        set x [expr { round( $x1 + $x_delta * ( $xval - $fx_min ) / $fx_range ) } ]
        set y [expr { round( $y2 - $y_delta * ( $yval - $fy_min ) / $fy_range ) } ] 
        # plot x, y
        mll_draw_image_path_color $filename [list $x $y] "#ff00ff"
    }

    set time_end [clock seconds]
    set time_elapsed [expr { round( ( $time_end - $time_start ) / 6.) / 10. } ]
    puts "Time elapsed: ${time_elapsed} minutes."
}

proc hex2dec {largeHex} {
    # This proc from http://wiki.tcl.tk/3242 hexadecimal conversions
    # Retrieved 2017-10-07
    set res 0
    foreach hexDigit [split $largeHex {}] {
        set new 0x$hexDigit
        set res [expr {16*$res + $new}]
    }
    return $res
}

proc hex2dec_color { string } {
    upvar 1 __hex_color_arr hex_arr
    # Returns hexadecimal as a number.
    # If hexadecimal is more than two digits,
    # returns a list of decimal numbers for each two hex digits
    set string_len [string length $string]
    set hex ""
    set dec_list [list ]
    set dec ""
    if { [expr { $string_len % 2 } ] eq 0 } {
        
        for {set j 0} {$j < $string_len} {incr j 2} {
            set s [string range $string $j $j+1]
            if { [info exists hex_arr(${s}) ] } {
                set dec $hex_arr(${s})
            } else {
                scan $s %x dec
                if { $dec < 0 } {
                    puts -nonewline "hex2dec_color s $s dec $dec -->"
                    set dec [hex2dec $s]
                    puts $dec
                }
                if { $dec > 255 } {
                    puts -nonewline "hex2dec_color s $s dec $dec -->"
                    set dec [hex2dec $s]
                    puts $dec
                }
                set hex_arr(${s}) $dec
            }
            lappend dec_list $dec
        }
    }
    if { [llength $dec_list ] < 2 } {
        set r [lindex $dec_list 0 ]
    } else {
        set r $dec_list
    }
    return $r
}

proc dec2hex_color { number_list } {
    upvar 1 __dec_color_arr dec_arr
    # Assumes each number is between 0 and 255 inclusive
    # If only one number, returns value as element outside of list.
    set num_list_len [llength $number_list]
    set hex_list [list ]
    set h2d_list [list 0 1 2 3 4 5 6 7 8 9 a b c d e f]
    foreach num $number_list {
        if { $num < 0 || $num > 255 } {
            puts "dec2hex_color num $num out of bounds"
            if { $num < 0 } {
                set num 0
            } else {
                set num 255
            }
        }
        if { [info exists dec_arr(${num}) ] } {
            set hex $dec_arr(${num})
        } else {
            set hex [format %x $num]
            set hex_len [string length $hex]
            if { $hex_len  == 1 } {
                set hex "0${hex}"
            }
            if { $hex_len > 2 || $hex_len eq 0 } {
                # try slower way
                puts -nonewline "dec2hex_color $num to $hex --> "
                set r_idx [expr { $num % 16 } ]
                set l_idx [expr { $num / 16 } ]
                set hex [lindex $h2d_list $l_idx]
                append hex [lindex $h2d_list $r_idx]
                puts $hex
            }
            set dec_arr(${num}) ${hex}
        }
        lappend hex_list $hex
    }
    if { [llength $hex_list ] < 2 } {
        set h [lindex $hex_list 0]
    } else {
        set h $hex_list
    }
    return $h
}

proc qaf_interpolatep1p2_at_x {p1_x p1_y p2_x p2_y p3_x} {
    # gpl v2. from github.com/xdcpm/accounts-finance.git package
    set x_diff [expr { $p2_x - $p1_x } ]
    
    if { $x_diff == 0 } {
        set p3_y $p1_y
    } else {
        set y_diff [expr { $p2_y - $p1_y } ]
        set x3_diff [expr { $p3_x - $p1_x } ]
        set x_pct_diff [expr { $x3_diff / $x_diff } ]
        set p3_y [expr { $x_pct_diff * $y_diff + $p1_y } ]
    }
    return $p3_y
}

proc mml_rainbow { pct } {
    # expects a number from 0 to 100
    # to represent range:
    # 0 = red
    # orange
    # yellow
    # green
    # blue
    # indigo
    # 100 = violet
    
    # Physical range:
    # wavelength: 390 to 700 nm
    #   here: 740 to 380 nm
    # 
    # frequency: 430-770 THz
    #   here: 405 to 788
    # adjusted to: 406 to 786
    # Use frequency to simplify math
    #set f [expr { ( 786 - 407 ) * $pct / 100. + 407. } ]
    set f [expr { 3.79 * $pct + 407. } ]
  #  puts "pct $pct f $f "
    # convert hex to decimal:
    #  hexadecimal value in $hex
    #  decimal value in dec
    #  scan $hex %x dec

    # convert decimal to hex:
    #  set hex [format %x $dec] (for a-f)
    #  set hex [format %X $dec] (for A-F)
    
    # See https://en.wikipedia.org/wiki/Visible_spectrum
    
    # Color Wavelength Frequency Photon energy
    # violet 380–450 nm 668–789 THz 2.75–3.26 eV
    # blue 450–495 nm 606–668 THz 2.50–2.75 eV
    # green 495–570 nm 526–606 THz 2.17–2.50 eV
    # yellow 570–590 nm 508–526 THz 2.10–2.17 eV
    # orange 590–620 nm 484–508 THz 2.00–2.10 eV
    # red 620–750 nm 400–484 THz 1.65–2.00 eV
    # returns a representative color of the rainbow
    
    # https://en.wikipedia.org/wiki/Spectral_color which includes:
    # https://en.wikipedia.org/wiki/Spectral_color#Table_of_spectral_or_near-spectral_colors

    # worksheet
    set mps 299792458
    set nmps [expr $mps * 1e+9]
    # example f:
    #set f 570
    #set hz expr $nmps /$f 
    set thz [expr $nmps /( $f * 1e12)]
    #set thz expr $hz / 1e12

    upvar 1 __rainbow_ol r_ol
    # Table as a list of lists:
    # rainbow_ol
    # rgb w f description(from wikipedia page ref above)
    if { ![info exists r_ol] } {
        set r_ul [list \
                      [list 990011 740 405 "xtreme red"] \
                      [list cc0011 700 428 "wide gamut RGB red"] \
                      [list ff0000 633 473 "He-Ne laser"] \
                      [list ff8000 605 497 "carmine dye"] \
                      [list ffc000 589 508 "orange interpreted"] \
                      [list ffd300 583 513 "nearly gold"] \
                      [list ffe000 577 519 "Munsell 5Yellow"] \
                      [list ffef00 574 522 "canary yellow"] \
                      [list ffff00 570 526 "yellow"] \
                      [list dfff00 567 529 "Chartreuse yellow"] \
                      [list bfff00 564 532 "lime"] \
                      [list 7fff00 558 537 "Chartreuse green"] \
                      [list 66ff00 556 539 "Bright green"] \
                      [list 3fff00 552 543 "Harlequin"] \
                      [list 00cc33 525 571 "Wide-gamut RGB green"] \
                      [list 00ba5c 517 580 "medium spring green (adjusted)"] \
                      [list 009f6b 506 592 "green NCS"] \
                      [list 009f77 503 597 "Munsell 5Green"] \
                      [list 00b5aa 499 601 "Turquoise (adjusted)"] \
                      [list 00b7eb 493 608 "cyan"] \
                      [list 007fff 488 614 "Azure sRGB"] \
                      [list 0055aa 482 622 "Munsell 5Blue"] \
                      [list 0000ff 452 663 "Blue RGB"] \
                      [list 3300ff 446 672 "Indigo"] \
                      [list 440099 380 788 "Violet"] ]
        set r1_ol [lsort -integer -index 2 $r_ul]
        set r_ol [list ]
        foreach f_set $r1_ol {
            set freq [lindex $f_set 2]
            set color [lindex $f_set 0]
            scan [string range $color 0 1] %x r
            scan [string range $color 2 3] %x g
            scan [string range $color 4 5] %x b
            set f_set_list [list $freq $r $g $b]
            lappend r_ol $f_set_list
        }
    }
    set r_ol_len [llength $r_ol]
    set i 0
    while { [lindex [lindex $r_ol $i] 0] <= $f && $i < $r_ol_len} {
        
        incr i
    }
    set f1_set [lindex $r_ol $i-1]
    set f1 [lindex $f1_set 0]
    set r1 [lindex $f1_set 1]
    set g1 [lindex $f1_set 2]
    set b1 [lindex $f1_set 3]
    
    set f2_set [lindex $r_ol $i]
    set f2 [lindex $f2_set 0]
    set r2 [lindex $f2_set 1]
    set g2 [lindex $f2_set 2]
    set b2 [lindex $f2_set 3]
#    if { ( $f < $f1 && $f1 ne "" ) || ( $f > $f2 && $f2 ne "" ) } {
#        puts "while-error: f $f f1_set '$f1_set' f2_set '$f2_set'"
#    }
    set color_hex ""
    if { $f eq $f1 || [llength $f2_set] ne 4 || $f2 eq $f1 } {
        set p_hex [dec2hex_color [list $r1 $g1 $b1]]
    } else {
        # interpolate

#        set p_rel [expr { ( $f - $f1 ) / ( $f2 - $f1 + 0. ) } ]
        set r [qaf_interpolatep1p2_at_x $f1 $r1 $f2 $r2 $f]
        set g [qaf_interpolatep1p2_at_x $f1 $g1 $f2 $g2 $f]
        set b [qaf_interpolatep1p2_at_x $f1 $b1 $f2 $b2 $f]
        set r [expr { int( round( $r ) ) } ]
 #       if { $r < 0 || $r > 255 } {
 #           puts -nonewline "r $r p_rel $p_rel f1 $f1 r1 $r1 f2 $f2 r2 $r2 f $f: "
 #           puts [expr { int( round( $p_rel * ($r2 - $r1) / ($f2 - $f1 + 0.) ) ) } ]
 #       }
        set g [expr { int( round( $g ) ) } ]
 #       if { $g < 0 || $g > 255 } {
 #           puts -nonewline "g $g p_rel $p_rel f1 $f1 g1 $g1 f2 $f2 g2 $g2 f $f: "
 #           puts [expr { int( round( $p_rel * ($g2 - $g1) / ($f2 - $f1 + 0.) ) ) } ]
 #       }
        set b [expr { int( round( $b ) ) } ]
 #       if { $b < 0 || $b > 255 } {
 #           puts -nonewline "b $b p_rel $p_rel f1 $f1 b1 $b1 f2 $f2 b2 $b2 f $f: "
 #           puts [expr { int( round( $p_rel * ($b2 - $b1) / ($f2 - $f1 + 0.) ) ) } ]
 #       }

        set p_hex [dec2hex_color [list $r $g $b]]
    }
    set color_hex [join $p_hex]
    
    return $color_hex
}

proc mml_new_filename { filename x y} {
    exec gm convert -size ${x}x${y} "xc:#ffffff" $filename
    
}

proc mml_path_spec { list_of_points } {
    # each point consists of x and y.
    # move to first point, then draw to each that follows
    set path_specification ""
    set movement_type "M"
    foreach {x y} $list_of_points {
        append path_specification "${movement_type} $x $y"
        set movement_type " L"
    }
    return $path_specification
}

proc mml_draw_path { color list_of_points filename } {
    while { [llength $list_of_points] > 100  } {
        set path_segment [lrange $list_of_points 0 99]
        set list_of_points [lrange $list_of_points 98 end]
        exec gm convert -fill none -stroke $color -draw "path '[mml_path_spec $path_segment ]'" $filename $filename
        #        puts "path_segment $path_segment"
    }
    exec gm convert -fill none -stroke $color -draw "path '[mml_path_spec $list_of_points ]'" $filename $filename
    #    puts "list_of_points $list_of_points"
}


# 'draw' from: http://www.graphicsmagick.org/convert.html
# draw choices: from: http://www.graphicsmagick.org/GraphicsMagick.html#details-draw
# point           x,y
# line            x0,y0 x1,y1
# rectangle       x0,y0 x1,y1
# roundRectangle  x0,y0 x1,y1 wc,hc
# arc             x0,y0 x1,y1 a0,a1
# ellipse         x0,y0 rx,ry a0,a1
# circle          x0,y0 x1,y1
# polyline        x0,y0  ...  xn,yn
# polygon         x0,y0  ...  xn,yn
# Bezier          x0,y0  ...  xn,yn
# path            path specification (*See mml_path_spec ) 
# image           operator x0,y0 w,h filename
# For example:
#set path [mml_path_spec [list $x $y_min $x $y_max]]
#exec gm convert -stroke $color -strokewidth 1 -draw "path '${path}'" $new_file $new_file

#    exec gm convert -fill "#ffffff" -draw "rectangle 0,0 $x,$y" test.gif $filename
# exec gm convert -size ${x}x${y} "xc:#ffffff" -fill "#ff0000" -draw "rectangle 0,0 10,10" test1.png
