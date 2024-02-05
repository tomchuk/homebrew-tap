class ElasticsearchFull < Formula
  desc "Distributed search & analytics engine"
  homepage "https://www.elastic.co/products/elasticsearch"
  url "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.17.17-darwin-aarch64.tar.gz?tap=tomchuk/homebrew-tap"
  version "7.17.17"
  sha256 "979a8937ddebbc943904ae68c4f54f981a5de36ddc84416b51125544eb41c9f6"
  conflicts_with "elasticsearch"
  depends_on "openjdk"

  def install
    # Install everything else into package directory
    libexec.install "bin", "config", "lib", "modules"

    inreplace libexec/"bin/elasticsearch-env",
              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"$ES_HOME\"/config; fi",
              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"#{etc}/elasticsearch\"; fi"

    # Set up Elasticsearch for local development:
    inreplace "#{libexec}/config/elasticsearch.yml" do |s|
      # 1. Give the cluster a unique name
      s.gsub!(/#\s*cluster\.name\: .*/, "cluster.name: es")

      # 2. Configure paths
      s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/lib/elasticsearch/")
      s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/elasticsearch/")
    end

    inreplace "#{libexec}/config/jvm.options", %r{logs/gc.log}, "#{var}/log/elasticsearch/gc.log"

    # Move config files into etc
    (etc/"elasticsearch").install Dir[libexec/"config/*"]
    (libexec/"config").rmtree

    Dir.foreach(libexec/"bin") do |f|
      next if f == "." || f == ".." || !File.extname(f).empty?

      bin.install libexec/"bin"/f
    end
    bin.env_script_all_files(libexec/"bin", JAVA_HOME: Formula["openjdk"].opt_prefix)

    system "codesign", "-f", "-s", "-", "#{libexec}/modules/x-pack-ml/platform/darwin-x86_64/controller.app", "--deep"
  end

  def post_install
    # Make sure runtime directories exist
    (var/"lib/elasticsearch/es").mkpath
    (var/"log/elasticsearch").mkpath
    ln_s etc/"elasticsearch", libexec/"config"
    (var/"elasticsearch/plugins").mkpath
    ln_s var/"elasticsearch/plugins", libexec/"plugins"
  end

  def caveats
    s = <<~EOS
      Data:    #{var}/lib/elasticsearch/es/
      Logs:    #{var}/log/elasticsearch/es.log
      Plugins: #{var}/elasticsearch/plugins/
      Config:  #{etc}/elasticsearch/
    EOS

    s
  end

  service do
    run opt_bin/"elasticsearch"
    working_dir var
    log_path var/"log/elasticsearch.log"
    error_log_path var/"log/elasticsearch.log"
  end

  test do
    require "socket"

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    mkdir testpath/"config"
    cp etc/"elasticsearch/jvm.options", testpath/"config"
    cp etc/"elasticsearch/log4j2.properties", testpath/"config"
    touch testpath/"config/elasticsearch.yml"

    ENV["ES_PATH_CONF"] = testpath/"config"

    system "#{bin}/elasticsearch-plugin", "list"

    pid = testpath/"pid"
    begin
      system "#{bin}/elasticsearch", "-d", "-p", pid, "-Expack.security.enabled=false", "-Epath.data=#{testpath}/data", "-Epath.logs=#{testpath}/logs", "-Enode.name=test-cli", "-Ehttp.port=#{port}"
      sleep 30
      system "curl", "-XGET", "localhost:#{port}/"
      output = shell_output("curl -s -XGET localhost:#{port}/_cat/nodes")
      assert_match "test-cli", output
    ensure
      Process.kill(9, pid.read.to_i)
    end

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    rm testpath/"config/elasticsearch.yml"
    (testpath/"config/elasticsearch.yml").write <<~EOS
      path.data: #{testpath}/data
      path.logs: #{testpath}/logs
      node.name: test-es-path-conf
      http.port: #{port}
    EOS

    pid = testpath/"pid"
    begin
      system "#{bin}/elasticsearch", "-d", "-p", pid, "-Expack.security.enabled=false"
      sleep 30
      system "curl", "-XGET", "localhost:#{port}/"
      output = shell_output("curl -s -XGET localhost:#{port}/_cat/nodes")
      assert_match "test-es-path-conf", output
    ensure
      Process.kill(9, pid.read.to_i)
    end
  end
end
