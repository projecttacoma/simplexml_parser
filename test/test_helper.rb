require_relative "./simplecov_init"
require_relative '../lib/simplexml_parser'

require 'pry'
require 'minitest/autorun'
require 'bundler/setup'

class Hash
  def diff_hash(other, ignore_id=false, clean_reference=true)
    (self.keys | other.keys).inject({}) do |diff, k|
      left = self[k]
      right = other[k]
      right = right.gsub(/_precondition_\d+/, '') if (right && k==:reference && clean_reference)
      unless left == right
        if left.is_a? Hash
          if right.nil?
            tmp = left
          else
            tmp = left.diff_hash(right,ignore_id)
          end
          diff[k] = tmp unless tmp.empty?
        elsif left.is_a? Array
          tmp = []
          left.each_with_index do |entry,i|
            if (right and right[i])
              if entry.is_a? Hash
                entry_diff = entry.diff_hash(right[i],ignore_id)
              elsif left != right
                entry_diff = left.to_s
              end
            else
              entry_diff = left.to_s
            end
            tmp << entry_diff unless entry_diff.empty?
          end
          diff[k] = tmp unless tmp.empty?
        elsif(left==nil && right && right.respond_to?(:empty?) && right.empty?)
          # do nothing so nil will match an empty hash or array
        elsif(!ignore_id || (k != :id && k!="id"))
          diff[k] = "EXPECTED: [#{left}], FOUND: [#{right}]"
        end
      end
      diff
    end
  end
end
