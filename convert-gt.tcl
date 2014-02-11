# file: convert-gt.tcl

proc import_climate_datafile { filename } {
    # returns data as a list of lists
    # in form:  $year_decimal $gt $error_amount $year $month
    set data_txt ""
    #  cfcount = climate file counter
    set cfcount 1
    set fileId [open $filename r]
    while { ![eof $fileId] } {
        #  Read entire file. 
        append data_txt [read $fileId]
    }
    close $fileId
    #  split is unable to split lines consistently with \n or \r
    #  so, splitting by everything, and recompiling each line of file.
    set data_set_list [split $data_txt "\n\r\t"]
    set table_list [list ]
    set line_count 0
    foreach {year gt error_amt} $data_set_list {
        #  data integrity check (minimal, because file is in a standard, tab delimited format).
        if { $year ne "" && $gt ne "" && $error_amt ne "" } {
            set year_ck [expr { ( 1. + $year ) / ( $year + 1. ) } ]
            set gt_ck [expr { ( 1. + $gt ) / ( $gt + 1. ) } ]
            #  error_amt is a positive real number > 0
            set error_amt_ck [expr { round( $error_amt /  abs( $error_amt ) ) == 1 } ]
            if { $year < 1978 || $year > 2013 } {
                set year_ck 0
            }
            if { $year_ck && $gt_ck && $error_amt_ck } {
                set line_v2 [list $year $gt $error_amt]
                lappend table_list $line_v2
                incr line_count
            } else {
                puts "This data point did not pass integrity check. Ignored:"
                puts "year $year, gt $gt, error $error_amt"
            }
        }
    }
    #  table_list is a list of lists.
    puts "$filename has $line_count data points."
    
    #  Sort data chronologically so that changes per unit time can be tracked.
    #  Sort table_list by year_dec_input. There should only be one per interval.
    set table_list [lsort -index 0 -real -increasing $table_list]
    
    #  Data in this format:
    #  year_decimal = YYYY + (MM-1)/12 + 1/24, where YYYY-MM is year and month
    #  gt      = offset of temperature in Celsius from reference temperature.
    #  error_amt     = measurement error.
    set cpcount 0
    set return_list [list ]
    set title_row [list year_decimal global_temp error_amount year month]
    lappend return_list $title_row
    foreach row_list $table_list {
        incr cpcount 
        set year_dec_input [lindex $row_list 0]
        set gt [lindex $row_list 1]
        set error_amt [lindex $row_list 2]
        # ..............................................................
        #  Calculations
        #  Re-calculate year_decimal
        set year [expr { int( $year_dec_input ) } ]
        set numerator_over_24 [expr { round( ( $year_dec_input - $year ) * 24. ) } ]
        set month [expr  { round( ( $numerator_over_24 + 1. ) / 2. ) } ]
        #  Following is consistent with earthquake year_decimal calculation:
        set year_decimal [expr { $year + ($month - 1. ) / 12. + 1./24. } ]
        # puts "year_dec $year_dec_input, gt $gt, error_amt $error_amt, year $year, numerator/24 $numerator_over_24, month $month, year_decimal $year_decimal"
        
        #  data integrity check (minimal, because file is in a standard, tab delimited format).
        if { $year ne "" && $gt ne "" && $error_amt ne "" } {
            set year_ck [expr { ( 1. + $year ) / ( $year + 1. ) } ]
            set gt_ck [expr { ( 1. + $gt ) / ( $gt + 1. ) } ]
            #  error_amt is a positive real number > 0
            set error_amt_ck [expr { round( $error_amt /  abs( $error_amt ) ) == 1 } ]
            if { $year < 1978 || $year > 2013 } {
                set year_ck 0
            }
            if { $year_ck && $gt_ck && $error_amt_ck } {
                set line_v2 [list $year $gt $error_amt]
                lappend table_list $line_v2
                incr line_count
            } else {
                puts "This data point did not pass integrity check. Ignored:"
                puts "year $year, gt $gt, error $error_amt"
            }
        }
        
        
        # ..............................................................
        # Build data list of lists
        set row [list $year_decimal $gt $error_amt $year $month]
        #  Save year and month format.
        #  Grouping by year and month avoids introducing possible rounding and number value mismatch errors from
        #  decimal math when using year_decimal values.
        lappend return_list $row
    }
    puts "$cpcount data points imported."
    return $return_list
}


