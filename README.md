[![Dependency Status](https://gemnasium.com/sul-dlss/gdor-indexer.svg)](https://gemnasium.com/sul-dlss/gdor-indexer)

h1. gdor-indexer

Code to harvest DOR druids via DOR Fetcher service, mods from PURL, and use it to index items into a Solr index, such as that for SearchWorks.

h2. Prerequisites

1. ruby
2. bundler gem must be installed

h2. Install steps for running locally

Add this line to your application's Gemfile:

    gem 'harvestdor-indexer'

Then execute:

    $ bundle

h2. Configuration

h4. Create a collections folder in the config directory:

    $ cd /path/to/gdor-indexer/config
    $ mkdir collections

h4. Create a yml config file for your collection(s) to be harvested and indexed.

See ```spec/config/walters_integration_spec.yml``` for an example.  Copy that file to ```config/collections``` and change the following settings:

* whitelist
* dor_fetcher service_url
* harvestdor log_dir and log_name
* solr_url

h5. whitelist

The whitelist is how you specify which objects to index.  The whitelist can be

* an Array of druids inline in the config yml file
* a filename containing a list of druids (one per line)

If a druid, per the object's identityMetadata at purl page, is for a

* collection record:  then we process all the item druids in that collection (as if they were included individually in the whitelist)
* non-collection record: then we process the druid as an individual item

h4. Run the indexer script

    $ cd /path/to/gdor-indexer
    $ nohup ./bin/indexer -c my_collection &>path/to/nohup.output

h2. Running the tests

  ```$ rake```

h2. Contributing

* Fork it (https://help.github.com/articles/fork-a-repo/)
* Create your feature branch (`git checkout -b my-new-feature`)
* Write code and tests.
* Commit your changes (`git commit -am 'Added some feature'`)
* Push to the branch (`git push origin my-new-feature`)
* Create new Pull Request (https://help.github.com/articles/creating-a-pull-request/)

