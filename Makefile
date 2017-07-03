PHONY: build

build:
	ruby build.rb
	zip pnr-gtfs.zip -j gtfs gtfs/*
