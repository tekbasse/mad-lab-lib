# file: convert-eq.tcl
#  This is a demo file showing an example of how to use mad-lab-lib.tcl
#  Mad-Lab-lib is open source and published under the GNU General Public License

#  license
#  Copyright (c) 2013 Benjamin Brink
#  po box 20, Marylhurst, OR 97036-0020 usa
#  email: tekbasse@yahoo.com

#  A local copy is available at LICENSE.txt

proc import_earthquake_datafile { filename } {
    # input earthquake datafile, returns content as list of lists
    set data_html ""
    set fileId [open $filename r]
    while { ![eof $fileId] } {
        gets $fileId line
        append data_html $line
    }
    close $fileId
    
    # remove open TABLE tag and everything before it.
    regsub -nocase -- {^.* <table[^>]+[>]} $data_html {} data_2_html
    # remove close TABLE tag and everything after it.
    regsub -nocase -- {</table>.*$} $data_2_html {} data_3_html
    # convert BR tags to space
    regsub -nocase -all -- {<br>} $data_3_html { } data_4_html
    # remove TBODY tag
    regsub -nocase -all -- {<tbod[^>]+[>]} $data_4_html {} data_5_html
    # remove close TR tags
    regsub -nocase -all -- {</tr>} $data_5_html {} data_6_html
    # remove any existing tabs and newlines
    regsub -nocase -all -- {\t\n} $data_6_html {} data_7_html
    # remove extra spaces
    regsub -nocase -all -- {[ ]+} $data_7_html { } data_8_html
    # convert open TR tags to new lines
    regsub -nocase -all -- {<tr[^>]*[>]} $data_8_html "\n" data_9_html
    # convert TD and TH tags to tab delimiters
    regsub -nocase -all -- {<t[hd][^>]*[>]} $data_9_html "\t" data_10_html
    # remove any remaining close html tags
    regsub -nocase -all -- {</[^>]+[>]} $data_10_html {} data_11_html
    # remove A tags, but leave the wrapped references
    regsub -nocase -all -- {<a[ ]+href[^>]+[>]} $data_11_html {} data_12_txt
    
    #    puts "data_12_txt: $data_12_txt"
    set data_12_list [split $data_12_txt "\n"]
    set table_list [list ]
    set line_count 0
    foreach line $data_12_list {
        incr line_count
        set line_v2 [split $line "\t"]
        set line_v2_cols [llength $line_v2]
        if { $line_v2_cols > 8 } {
            # Line contains 9 or 10 cols, including extra blank ones we introduced when removing html above.
            while { $line_v2_cols > 9 && [string trim [lindex $line_v2 0]] eq "" } {
                set line_v2 [lrange $line_v2 1 end]
                incr line_v2_cols -1
            }
            set line_v3 $line_v2
            
            set line_v4 [list ]
            foreach column $line_v3 {
                set val_new [string trim $column]
                lappend line_v4 $val_new
            }
            set line_v4_cols [llength $line_v4]
            if { $line_v4_cols != 9 } {
                puts "Error. $line_v4_cols columns for '$line_v4'"
            } else {
                lappend table_list $line_v4
            }
        } else {
            puts "This line of $line_v2_cols columns was not processed: '$line_v2'"
        }
    }
    
    # Table columns in this sequence, header, and data format:
    # Magnitude   "Mag"              real number N.N 
    # Depth       "Depth km"         real number N.N
    # Day         "Day"              YYYY-MM-DD
    # Time        "Time UTC"         NN:NN:NN
    # Latitude    "Lat"              real number +N.N
    # Longitude   "Lon"              real number +N.N
    # Region      "Region"           [A-Z0-9, \.\-]
    # Event ID    "Explore Event ID" integer
    # Timestamp   "Timestamp"        wide integer
    
    # epcounter = earthquake-data point count
    set epcount 0
    set has_title_p 0
    set row_list [lindex $table_list 0]
    if { [lindex $row_list 0] eq "Mag" } {
        # ignore. This is a title row
        #puts "Ignoring title row: $row_list"
        set table_list [lrange $table_list 1 end]
    }

    # ..............................................................
    # data integrity check and convert to return_list 
    set return_lists [list ]
    set title_row [list mag depth day time_utc lat lon region event_id timestamp_epoch energy_joules year month year_decimal energy_error_min energy_error_max energy_error]

    foreach row_list $table_list {
        set mag [lindex $row_list 0]
        set depth [lindex $row_list 1]
        set day [lindex $row_list 2]
        set time_utc [lindex $row_list 3]
        set lat [lindex $row_list 4]
        set lon [lindex $row_list 5]
        set region [lindex $row_list 6]
        set event_id [lindex $row_list 7]
        set timestamp_epoch [lindex $row_list 8]
        # Error if any data doesn't pass a type check.
        # The checks for real number convert a number to 1, which is "yes" in tcl logic.
        # Each set of depth, lat and lon can have a values of 0,
        #  so adding 1 to numerator and denominator satisfy those cases.
        set mag_ck [expr { round( $mag / $mag ) } ]
        set depth_ck [expr { round( ( 1. + $depth) / ( 1. + $depth ) ) } ]
        set day_ck [regexp -- {^[1-2][0-9][0-9][0-9][\-][0-9][0-9][\-][0-9][0-9]$} $day match]
        set time_utc_ck [regexp {^[0-9][0-9][\:][0-9][0-9][\:][0-9][0-9]$} $time_utc match]
        set lat_ck [expr { round( ( $lat + 1. ) / ( $lat + 1. ) ) } ]
        set lon_ck [expr { round( ( $lon + 1. ) / ( $lon + 1. ) ) } ]
        set region_ck [regexp -nocase -- {^[A-Z0-9 ,\.\-]+$} $region match]
        set event_id_ck [regexp -- {^[0-9]+$} $event_id match]
        set timestamp_epoch_ck [regexp -- {^[0-9]+$} $timestamp_epoch match]
        
        if { $mag_ck && $depth_ck && $day_ck && $time_utc_ck && $lat_ck && $lon_ck && $region_ck && $event_id_ck && $timestamp_epoch_ck } {
            # increment epcount in preparation for next point
            incr epcount

            #  Focus on energy, depth, and time interval of occurance.
            #  Earthquake energy depends on magnitude
            #  Time interval (a year_decimal used by climate data) depends on day.

            #  Calculate energy in ergs
            #  energy = (10^1.5)^mag (as a ratio comparison) per http://earthquake.usgs.gov/learn/topics/how_much_bigger.php
            #  Me = 2/3 log10E - 2.9 from: http://earthquake.usgs.gov/learn/topics/measure.php
            
            #  seismic moment, Moment energy (Me) = 10^( (3*$mag/2) + 16.1 ) 
            #  where: moment is in dyne-centimeters. 
            #         1 dyne-centimeter = 1 erg
            #         10 000 000 dyne-centimeters = 1 newton-meter
            #  from: http://www.ajdesigner.com/phpseismograph/earthquake_seismometer_moment_magnitude_conversion.php
            
            #  set Me  { pow(10.,16.1 + 3. * $mag / 2.) }
            #  Seismic wave energy (E) = Mo / 2000.
            #  since:
            #  log E = 1.5 * $mag + 11.8 (Gutenberg-Richter magnitude-energy relation)
            #  E = 10 ^ (1.5 * $mag + 11.8 )
            #  from: http://www.jclahr.com/alaska/aeic/magnitude/energy_calc.html
            
            #  USGS reference uses 16.1 instead of the Gutenberg-Richter magnitude-energy relation use of 11.8.
            #  For this exercise, the energy value isn't as important as the change in energy.
            #  Therefore, am using '16.1', which might exagerate differences.

            # Since the earthquake energies are large, the unit of energy is changed from Ergs to joules,
            # where 10^7 ergs = 1 joule and 10^18 joules = 1 Exajoule
            set eq_unit_conv_factor [expr { pow(10,-7) } ]
            set energy_units Joules
            set energy [expr { pow( 10. , 1.5 * $mag + 16.1) * $eq_unit_conv_factor } ]
            
            #  Calculate a year_decimal for $day that is consistent with global temperature data.
            #  There are fewer significant digits of year_decimals in the climate data.
            #  To match up earthquake and climate time intervals, both time sets are re-calculated using 
            #  math from this program by first converting the data to YYYY-MM format, then
            #  calculating year_decimal as YYYY + ( MM - 1 )/12 + 1/24.
            regexp {^([1-2][0-9][0-9][0-9])-([0-9][0-9])-[0-9][0-9]$} $day match year month
            #  Remove a leading zero digit in a month to avoid tcl interpreting month as an octal number
            regsub -- {^0([1-9])$} $month {\1} month
            set year_decimal [expr { $year + ($month - 1. ) / 12. + 1./24. } ]
            
            #  For earthquake error, assume the worst case, which is one significant digit of a higher magnitude
            #  since lower magnitudes represent less energy.
            set mag_error_max [expr { $mag + 0.1 } ]
            set mag_error_min [expr { $mag - 0.1 } ]
            set energy_error_max [expr { pow( 10. , 1.5 * $mag_error_max + 16.1) * $eq_unit_conv_factor } ]
            set energy_error_min [expr { pow( 10. , 1.5 * $mag_error_min + 16.1) * $eq_unit_conv_factor } ]
            #  energy error is half of range between energy of next higher magnitude - energy at next lower magnitude
            set energy_error [expr { ( $energy_error_max - $energy_error_min ) / 2. } ]
            #  Grouping by year and month avoids introducing possible rounding and number value mismatch errors from 
            #  decimal math when using year_decimal values.
            #puts "mag $mag energy $energy min $energy_error_min max $energy_error_max"
            set return_row_list [list $mag $depth $day $time_utc $lat $lon $region $event_id $timestamp_epoch $energy $year $month $year_decimal $energy_error_min $energy_error_max $energy_error]

            lappend return_lists $return_row_list
        } else {
            puts "Integrity error for row: $return_row_list"
            puts "mag $mag_ck, depth $depth_ck, day $day_ck, time $time_utc_ck, lat $lat_ck, lon $lon_ck, region $region_ck, event_id $event_id_ck, timestamp $timestamp_epoch_ck"
        }
        # next table_list row
    }
    
    # ..............................................................
    # Sort data chronologically so that changes per unit time can be tracked.
    set return_list [lsort -index 8 -integer -increasing $return_lists]
    
    set row_count [llength $return_lists]
    puts "There are $row_count data points."
    set return_lists [linsert $return_lists 0 0 $title_row]
    return $return_lists
    #puts "mag: $mag, energy: $energy, depth: $depth, day: $day, year: $year, month: $month, dYear: $year_decimal, timestamp_epoch $timestamp_epoch"
}
