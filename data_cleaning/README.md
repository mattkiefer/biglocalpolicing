# Data Cleaning

I've kept data cleaning here fairly minimal, mostly limited to the fields we intend to be using for our analysis.

Right now, that means we have the following fields in our data:

- date (YYYY-MM-DD)
- time (HH:MM:SS)
- year (the year in which a stop occurred)
- lat (the raw, unchanged latitude),
- lng (the raw, unchanged longitude),
- subject_race (a spelled-out combination of the Race and Ethnicity fields)
    - In every case in which "H" occurs in the Ethnicity fields, I replaced subject_race with Hispanic
    - In the other cases, I used the race field, replacing "A" with "asian/pacific islander", "B" with "black",
        "I" with "native american," "U" with "unknown", and "W" with "white"
- search_conducted (corresponds to values in the SearchType field that involve a search) (this is the same as OPP's script)
- county_name (the county name, with the same formatting OPP uses)
- reason_for_stop (the raw stop reason with some string cleaning)
- violation_type (a mapped value connecting the violation fields the WSU team used and the reason_for_stop)
- consent_search_conducted (a field specifically designed to state whether a given search was a consent search)
- raw_search_type (this is the original, raw SearchType value -- OPP cleaned this into the search_basis field)

## Installing/Preparing

The file containing the script for cleaning Montana's data is at `clean_mt.R`. 

It requires the following packages in R:

```R
library(tidyverse)
library(lubridate)
library(janitor)
library(hashmap)
library(stringr)
```

The violation codes are available in `violation_codes.csv`. 

In order to download the raw data, type:

```shell
wget https://stacks.stanford.edu/file/druid:zg129by0941/MT-raw.tar.gz
tar xvzf MT-raw.tar.gz
rm Mt-raw.tar.gz
```

(Note: the `rm` is optional; it simply removes the compressed file, which you don't need any more, since you uncompressed the file.)

Then, you need to combine all of the datasets in the `MT_original_csv` folder into a single file. I named mine `combined_mt.csv`, but you can set
that to whatever you want by changing the `RAW_DATA_PATH` variable.

There are a number of ways to do this. I personally used `xsv`, which is a great csv command-line toolkit.

```shell
fNames="$(ls MT_original_csv/*.csv -1)"
xsv cat fNames > combined_mt.csv
```

But it's also simple to do in Python:

```python
import pandas as pd
import glob

df = pd.DataFrame()

for fname in glob.glob("MT_original_csv/*.csv"):
    # note that you need this equal sign because despite its name, pandas append isn't an inplace operation
    df = df.append(pd.read_csv(fname))

df.to_csv("combined_mt.csv")
```

Or, [seemingly](https://stackoverflow.com/questions/33565199/how-to-append-multiple-files-in-r), in R.

Finally, you can create the cleaned file:

```shell
Rscript clean_mt.R
```

This will create a cleaned file called `cleaned_mt.csv`. You can change that easily, using the `OUTPUT_PATH` variable at the top of the file.