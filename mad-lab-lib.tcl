# This works:
# gm convert gt-eq-plot-0-0.png -fill "#0000ff" -stroke "#0000ff" -draw 'path "M 50 55 L 60 65 L 70 75" circle 80,85 90,95 point 100,105' gt-eq-plot-0-0.png

# mad-lab-lib.tcl

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

proc gm_path_builder { list_of_points } {
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

proc image_width_height { filename } {
    # returns the width and height in pixels of filename as a list: width, height.
    # original from OpenACS photo-album pa_image_width_height
    set identify_string [exec gm identify $filename]
    regexp {[ ]+([0-9]+)[x]([0-9]+)[\+]*} $identify_string x width height
    return [list $width $height]
}


proc draw_image_path_color { imagename x_y_coordinates_list color {opacity 1} } {
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
        exec gm convert -fill $fillcolor -stroke $color -draw [gm_path_builder $path_segment ] $imagename $imagename
    }
    #puts "exec gm convert -fill none -stroke $color -draw [gm_path_builder $x_y_coordinates_list ] $imagename $imagename"
    set path [gm_path_builder $x_y_coordinates_list ]
    if { [string match "*point*" $path] } {
        #set fillcolor $color
        #puts "exec gm convert $imagename -fill $color -draw $path $imagename"
        exec gm convert $imagename -fill $color -draw $path $imagename
    } else {
        exec gm convert $imagename -fill $fillcolor -stroke $color -draw $path $imagename
    }
}

proc draw_image_rect_color { imagename x0 y0 x1 y1 fillcolor {bordercolor ""} {opacity 1} } {
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

proc annotate_image_pos_color { imagename x y color text } {
    # Annotate an image
    # To annotate with blue text using font 12x24 at position (100,100), use:
    #    gm convert -font helvetica -fill blue -draw "text 100,100 Cockatoo" bird.jpg bird.miff
    # from: http://www.graphicsmagick.org/convert.html
    # Do not specify font for now. For compatibility between systems, assume there is a gm default.
    # exec gm convert -font "courier new" -fill $color -draw "text $x,$y $text" $imagename $imagename
    exec gm convert -fill $color -draw "text $x,$y '$text'" $imagename $imagename
}

proc scale { x } {
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

proc list_of_lists_to_file { filename list_of_lists } {
    set fileId [open $filename w]
    foreach row $list_of_lists {
        puts $fileId [join $row \t]
    }
    close $fileId
}

proc pretty_metric { number {unit ""} {significand "1"} {ignore_units ""} } {
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
    set test_base_nbr 1e-24
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

proc graph_lol { {type "lin-lin"} filename region data_list_of_lists x_index y_index x_style y_style x_ticks_count y_ticks_count x_title y_title } {
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
            puts "graph_lol(324): Why isn't fx2_min $fx2_min less than fx_min $fx_min ?"
        }
        if { $fx2_max > $fx_max } {
            set fx_max $fx2_max
        } else {
            puts "graph_lol(327): Why isn't fx2_max $fx2_max greater than fx_max $fx_max ?"
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
            puts "graph_lol(343): Why isn't fy2_min $fy2_min less than fy_min $fy_min ?"
        }
        if { $fy2_max > $fy_max } {
            set fy_max $fy2_max
        } else {
            puts "graph_lol(348): Why isn't fy2_max $fy2_max greater than fy_max $fy_max ?"
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
        draw_image_path_color $filename [list $x_0 $y1 $x_0 $y2] "#eeeeee"
    }
    if { [string match "*origin*" $y_style] } {
        set y_0 [expr { round( $y2 - $y_delta * ( 0 - $fy_min ) / $fy_range ) } ]
        draw_image_path_color $filename [list $x1 $y_0 $x2 $y_0] "#eeeeee"
    }


    # x axis
    draw_image_path_color $filename [list $x1 $y2 $x2 $y2] "#ccccff"
    # x axis ticks
    set y_tick [expr { $y2 + 4 } ]
    set k1 [expr { $x_delta / ( $x_ticks_count * 1. ) } ]
    for {set i 0} {$i <= $x_ticks_count } {incr i} {
        set x_plot [expr { round( $x1 + $k1 * ( $i * 1. ) ) } ]
        draw_image_path_color $filename [list $x_plot $y2 $x_plot $y_tick] "#ccccff"
    }
    if { ![info exists width_px ] } {
        set width_px [lindex [image_width_height $filename] 0]
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
        annotate_image_pos_color $filename $y_tick $x_plot "#aaaaff" [pretty_metric $x "" 2 "c d da h"]
    }
    # rotate back.
    exec gm convert -rotate 90 $filename $filename

    # y axis, left side
    draw_image_path_color $filename [list $x1 $y1 $x1 $y2] "#ffaaaa"
    # y axis ticks
    set x_tick [expr { $x1 - 40 } ]
    if { $x_tick < 0 } {
        set x_tick 1
    }
    set k1 [expr { $y_delta / ( 1. * $y_ticks_count ) } ]
    set k2 [expr { $fy_range / ( $y_ticks_count * 1. ) } ]
    for {set i 0} {$i <= $y_ticks_count } {incr i} {
        set y_plot [expr { round( $y2 - $k1 * $i ) } ] 
        draw_image_path_color $filename [list $x1 $y_plot $x_tick $y_plot] "#ffaaaa"
        # add label
        set y_tick [expr { $y_plot - 6 } ]
        set y [expr { $k2 * ( $i * 1. ) + $fy_min } ]
        annotate_image_pos_color $filename $x_tick $y_tick "#ffaaaa" "[pretty_metric $y "" 2 "c d da h"]"
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
                draw_image_path_color $filename [list $x_min $y $x_max $y] "#99ccff"
            } else {
                puts "not: x_min $x_min < x $x < x_max $x_max"
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
            draw_image_path_color $filename [list $x $y_min $x $y_max] "#ffcc99"
        }
        incr i
    }

    # Titles
    set y_plot [expr  { $y1 - 20 } ]
    if { $y_plot < 0 } {
        set y_plot 1
    }
    annotate_image_pos_color $filename [expr { round( ( $x1 + $x2 - [string length $y_title] * 12 ) / 2. ) } ] [expr { $y_plot } ] "#ff0000" $y_title
    annotate_image_pos_color $filename [expr { round( ( $x1 + $x2 - [string length $x_title] * 12 ) / 2. ) } ] [expr { $y_plot + 20 } ] "#0000ff" $x_title

    # foreground
    foreach p_x_y $pxy_lists {
        set xval [lindex $p_x_y 0]
        set yval [lindex $p_x_y 1]
        set x [expr { round( $x1 + $x_delta * ( $xval - $fx_min ) / $fx_range ) } ]
        set y [expr { round( $y2 - $y_delta * ( $yval - $fy_min ) / $fy_range ) } ] 
        # plot x, y
        draw_image_path_color $filename [list $x $y] "#ff00ff"
    }

    set time_end [clock seconds]
    set time_elapsed [expr { round( ( $time_end - $time_start ) / 6.) / 10. } ]
    puts "Time elapsed: ${time_elapsed} minutes."
}
