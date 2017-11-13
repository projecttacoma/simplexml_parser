# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "simplexml_parser"
  s.summary = "A Gem for parsing MAT SimpleXml files into the health data standards HQMF Model"
  s.description = "A Gem for parsing MAT SimpleXml files into the health data standards HQMF Model"
  s.email = "tacoma-list@lists.mitre.org"
  s.homepage = "http://github.com/projecttacoma/simplexml_parser"
  s.authors = ["The MITRE Corporation"]
  s.version = '1.0.0'

  s.files = s.files = `git ls-files`.split("\n")

  s.add_dependency "health-data-standards", "3.7.0"
  s.add_dependency "tilt", "~> 2.0.1"
end
