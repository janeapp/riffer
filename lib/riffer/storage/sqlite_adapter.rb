# frozen_string_literal: true

require "sequel"

module Riffer
  module Storage
    class SqliteAdapter < Base
      def initialize(database: ":memory:", **options)
        super(**options)
        @db = Sequel.sqlite(database)
        setup_schema
      end

      def save(key, value)
        @db[:riffer_storage].insert_conflict(
          target: :key,
          update: {value: value, updated_at: Time.now}
        ).insert(key: key, value: value, created_at: Time.now, updated_at: Time.now)
      end

      def load(key)
        record = @db[:riffer_storage].where(key: key).first
        record ? record[:value] : nil
      end

      def delete(key)
        @db[:riffer_storage].where(key: key).delete
      end

      private

      def setup_schema
        @db.create_table?(:riffer_storage) do
          String :key, primary_key: true
          String :value, text: true
          DateTime :created_at
          DateTime :updated_at
        end
      end
    end
  end
end
