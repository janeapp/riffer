# frozen_string_literal: true
# rbs_inline: enabled

# <tt>Riffer.config.google_cloud.client</tt> accepts any object implementing +post+ and +post_stream+
# (see Riffer::HTTP::Client); this class is the default, not a required base. Paths are relative to
# the client's <tt>v1/projects/{project_id}/locations/{location}</tt> resource.
class Riffer::Providers::GoogleCloud::Client < Riffer::HTTP::Client
  # @rbs @project_id: String
  # @rbs @location: String
  # @rbs @credentials: untyped
  # @rbs @base_url: String
  # @rbs self.@application_default_credentials: untyped

  SCOPE = "https://www.googleapis.com/auth/cloud-platform" #: String

  # Both are interpolated into the endpoint's host or path.
  VALID_PROJECT_ID_PATTERN = /\A[a-z0-9.:-]+\z/ #: Regexp
  VALID_LOCATION_PATTERN = /\A[a-z0-9-]+\z/ #: Regexp

  # googleauth's metadata-server lookups (GCE, Cloud Run, GKE) go through a
  # process-wide google-cloud-env cache that detects reentrancy by Thread, so
  # two fibers inside it at once raise ThreadError. Every googleauth call that
  # can reach it holds this lock; Ruby's Mutex is fiber-aware, so waiters yield
  # to the scheduler instead of blocking the thread.
  AUTH_LOCK = Mutex.new #: Thread::Mutex

  # Memoized process-wide so every client shares one token cache.
  #--
  #: () -> untyped
  def self.application_default_credentials
    AUTH_LOCK.synchronize do
      @application_default_credentials ||= begin
        Riffer::Helpers::Dependencies.depends_on("googleauth")
        Google::Auth.get_application_default([SCOPE])
      end
    end
  end

  #--
  #: (location: String) -> String
  def self.base_url_for(location:)
    case location
    when "global" then "https://aiplatform.googleapis.com"
    when "us", "eu" then "https://aiplatform.#{location}.rep.googleapis.com"
    else "https://#{location}-aiplatform.googleapis.com"
    end
  end

  #--
  #: (Riffer::Config::GoogleCloud) -> Riffer::Providers::GoogleCloud::Client
  def self.from_config(config)
    project_id = config.project_id
    raise Riffer::ArgumentError, "Riffer.config.google_cloud.project_id must be set" unless project_id

    new(project_id: project_id, location: config.location, credentials: config.credentials)
  end

  # +credentials+ is a googleauth credentials object (anything responding to
  # +updater_proc+); +nil+ resolves Application Default Credentials.
  #--
  #: (project_id: String, location: String, ?credentials: untyped, ?base_url: String?, ?headers: Hash[String, String], ?connection: Faraday::Connection?) -> void
  def initialize(project_id:, location:, credentials: nil, base_url: nil, headers: {}, connection: nil)
    validate!(project_id, VALID_PROJECT_ID_PATTERN, "project_id")
    validate!(location, VALID_LOCATION_PATTERN, "location")
    super(headers: headers, connection: connection)

    @project_id = project_id
    @location = location
    @credentials = credentials
    @base_url = (base_url || self.class.base_url_for(location: location)).chomp("/")
  end

  private

  #--
  #: (String, Regexp, String) -> void
  def validate!(value, pattern, attribute)
    return if value.is_a?(String) && value.match?(pattern)

    raise Riffer::ArgumentError, "Invalid #{attribute}: #{value.inspect}"
  end

  #--
  #: (String) -> String
  def url_for(path)
    "#{@base_url}/v1/projects/#{@project_id}/locations/#{@location}/#{path}"
  end

  # googleauth refreshes only a missing or near-expiry token, so fibers queued
  # behind a refresh reuse its result. +updater_proc+ rather than +apply!+,
  # whose return value is the header String for some credential types and the
  # headers Hash for others (self-signed JWTs).
  #--
  #: () -> Hash[String, String]
  def headers
    credentials = @credentials || self.class.application_default_credentials
    auth = {} #: Hash[Symbol, String]
    AUTH_LOCK.synchronize { credentials.updater_proc.call(auth) }.transform_keys(&:to_s)
  end

  #--
  #: () -> String
  def error_label
    "Google Cloud"
  end
end
