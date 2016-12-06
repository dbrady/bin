#!/usr/bin/env ruby

# index_json.rb - Script to turn json blobs into searchable, related documents

# TODO: Remind myself YTF I even wanted this. I mean, it seems like a GREAT
# idea, but what was the originating use case? Probably something like wanting
# to find all of the indicator search results for specific drug_ids, etc? (Stuff
# I could *probably* do if I would actually learn how jq's magical selectors
# work.)

# Functional TL;DR: A big JSON blob is often a tiny database microcosm in
# itself, so throw it into a database FriendlyORM style.

# Index JSON - Given:
# - a collection of JSON documents
# - a way of extracting an id from each document
# - a conneciton to a database where we can create tables willy-nilly
#
# Emit:
# - A table containing indexed values of each element in the tree
# - An indexing/join table for that table
#
# E.g.:
# { "records": [
#   { "id": 1, "name": "Bob", "age": 42, "children": [ {"age": 12, "name": "Bobette"} ],
#   { "id": 2, "name": "Carol", "age": 40, "children": [ {"age": 14, "name": "Caroline"}, {"age": 12, "name": "Carroll"}]
# }
#
# And emit:
# create_table :records {|t| t.string json }
# create_table :index_records_by_name {|t| t.integer record_id, t.string name }
# add_index :index_records_by_name, :name
#
# CREATE TABLE records { id INTEGER NOT NULL AUTO_INCREMENT, json TEXT };
# CREATE TABLE index_records_by_name { record_id INTEGER NOT NULL, name TEXT };
# -- add an index on index_records_by_name
# -- whatever the syntax is to add a foreign key constraint record_id => records.id ?
#
