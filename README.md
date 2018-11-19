# sync-send.rb
- Check whether same script has been running
- Sync stated repositories using sync-script/* (based on configuration)
  - Stops process if any of the repository is unable to sync properly.
- Commits (contains list of files/directories + hash values for current and the after syncing hash values saved into files)
  - Named using current datetime.
- Diffs both commits (generates the diff file, contains files to add, modify, and delete)
  - Named using current commit hash value.
- Splits the generate diff into 1 GB parts + 1 file to describe the number of parts available for the commit
  - Maintains the commit hash value naming.
- Enqueues the split diffs + description file
- Sends up to 50 files via the HTTP curl command to DXX downloader HTTP server
- Cleans up commit and diff files based on configuration (set to 20 sets)

# sync-recv.rb
- Check whether same script has been running and generally the reverse of sync-send.rb
- Dequeues the queue state file and downloads files for each dequeued name from DXX downloader HTTP server.
- Loops and depending on queue state after dequeuing, chooses to:
  - [started empty] -> fetches description file from DXX downloader HTTP server and emplaces all the file names into the queue state file. If description file not present in DXX downloader HTTP server, stops receiving process.
  - [just emptied] -> means that current set of commit is complete, applies join to all the diff files and unzip the added/modified files, and delete the files to delete. Continues with the loop.
  - [not empty] -> means that some of the files are not yet uploaded, stops receiving process.
- Cleans up commit and diff files based on configuration (set to 20 sets)

# Notes
The hash values are used to ensure general integrity of the files across the two sets. For practicality, it targets only files and only uses (file path, file size) for each file to calculate the hash value, i.e. does not include date time and actual binary content.

Both sync-send.rb and sync-recv.rb checks whether the same script has been running in case the syncing takes super long and the next trigger of the running of the same script occurs. Running the same script more than once concurrently has undesirable consequences.
