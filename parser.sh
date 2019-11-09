#!/bin/bash

OUTPUT_CSV_FILE="steps.csv"

# Steps
# 0 1 2a 2b 3_1 3_2 4
# Optionally: 0 1 2 3 4 - goes automatically without prompting 
STEPS="4" 

# These events are grepped automatically
PAPI_EVENTS_CNTRS="PAPI_L3_TCM PAPI_L3_TCA" 
PAPI_EVENTS_FLOPS="PAPI_FP_OPS" 
# Derived cntrs
GREP_DERIVED_CNTRS="" # derived_L2_DMR derived_L3_TMR
GREP_DERIVED_FLOPS="derived_FLOPS" #  derived_SP_vector_FLOPS



function printHeader() {
    echo -n "Step;TIME CNTRS;" > $OUTPUT_CSV_FILE
    for event in $PAPI_EVENTS_CNTRS; do
        echo -n "${event};" >> $OUTPUT_CSV_FILE
    done

    for event in $GREP_DERIVED_CNTRS; do
        echo -n "${event};" >> $OUTPUT_CSV_FILE
    done

    echo -n "TIME FLOPS;" >> $OUTPUT_CSV_FILE
    for event in $PAPI_EVENTS_FLOPS; do
        echo -n "${event};" >> $OUTPUT_CSV_FILE
    done

    for event in $GREP_DERIVED_FLOPS; do
        echo -n "${event};" >> $OUTPUT_CSV_FILE
    done

    echo " " >> $OUTPUT_CSV_FILE
}

function parseOutCNTRS() {
    local step_num=$1;
    shift;
    local measure=$1;
    shift;

    local input_file=step${step_num}_$measure.out
    local output_file=$OUTPUT_CSV_FILE

    grep $input_file -e "wall time .* s" | grep -e "[0-9]*\.[0-9]*" -o | tr -d '\n' >> $output_file;
    echo -n ";" >> $output_file;

    for event in $PAPI_EVENTS_CNTRS; do
        grep $input_file -e "$event" | grep -E -e "[0-9]{1,}" -o | head -1 | tr -d '\n' >> $output_file;
        echo -n ";" >> $output_file;
    done

    for event in $GREP_DERIVED_CNTRS; do
        grep $input_file -e "$event" | grep -E -e "[0-9]{1,}\.{0,1}[0-9]{1,}" -o | head -1 | tr -d '\n' >> $output_file;
        echo -n ";" >> $output_file;
    done
}

function parseOutFLOPS() {
    local step_num=$1;
    shift;
    local measure=$1;
    shift;

    local input_file=step${step_num}_$measure.out
    local output_file=$OUTPUT_CSV_FILE

    grep $input_file -e "wall time .* s" | grep -e "[0-9]*\.[0-9]*" -o | tr -d '\n' >> $output_file;
    echo -n ";" >> $output_file;

    for event in $PAPI_EVENTS_FLOPS; do
        grep $input_file -e "$event" | grep -E -e "[0-9]{1,}\.{0,1}[0-9]{0,}" -o | head -1 | tr -d '\n' >> $output_file;
        echo -n ";" >> $output_file;
    done

    for event in $GREP_DERIVED_FLOPS; do
        grep $input_file -e "$event" | grep -E -e "[0-9]{1,}\.{0,1}[0-9]{1,}" -o | head -1 | tr -d '\n' >> $output_file;
        echo -n ";" >> $output_file;
    done
}

function execStep() {    
    local STEP_NUM=$1;
    shift;

    local STEP_NAME=$1;
    shift;
    
    local MEASURE=$1;
    shift;
    if [ "$MEASURE" = "CNTRS" ]; then
        local events="";
        for event in $PAPI_EVENTS_CNTRS; do
            events="${events}|${event}"
        done
        export PAPI_EVENTS="$events"
    elif [ "$MEASURE" = "FLOPS" ]; then
        local events="";
        for event in $PAPI_EVENTS_FLOPS; do
            events="${events}|${event}"
        done
        export PAPI_EVENTS="$events"
    fi

    local OUT_FILE=step${STEP_NAME}_${MEASURE}.out

    cmake .. -DCMAKE_BUILD_TYPE=Release -DWITH_PAPI=1 -DSTEPS="$STEP_NUM"; 
    make clean; 
    make -j; 
    ./Step"${STEP_NUM}"/ANN ../Data/network.h5 ../Data/bigDataset.h5 ./Step"${STEP_NUM}"/output.h5 > $OUT_FILE
}


# MAIN
# load libs
ml intel PAPI HDF5 CMake Python/3.6.1

printHeader

for step_name in $STEPS; do
    echo "*****************************************"
    echo "Current step: ${step_name}"
    echo "*****************************************"

    if [ "$step_name" = "2b" ] || [ "$step_name" = "3_2" ]; then
        echo "*****************************************"
        echo "Make the desired change in the step ${step_name} (in the original step's folder)"
        echo "*****************************************"
        read;
    fi

    if [ "$step_name" = "2a" ] || [ "$step_name" = "2b" ]; then
        step_exec=2
    elif [ "$step_name" = "3_1" ] || [ "$step_name" = "3_2" ]; then
        step_exec=3
    else 
        step_exec=$step_name;
    fi

    execStep $step_exec $step_name CNTRS
    execStep $step_exec $step_name FLOPS
    echo -n "Step${step_name};" >> $OUTPUT_CSV_FILE
    parseOutCNTRS $step_name CNTRS
    parseOutFLOPS $step_name FLOPS
    echo " "  >> $OUTPUT_CSV_FILE
done

echo FINISHED!
