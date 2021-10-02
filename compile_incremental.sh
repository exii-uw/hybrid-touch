#!/bin/bash

./compare.py --csv data/october > export/october.csv
cmd /c 'jupyter nbconvert --to html results/incremental.ipynb'
cmd /c 'jupyter nbconvert --to pdf --template article results/incremental.ipynb'
