# This file was generated by GoReleaser. DO NOT EDIT.
class Ecctl < Formula
  desc "Elastic Cloud Control, the official Elastic Cloud and ECE command line interface"
  homepage "https://github.com/elastic/ecctl"
  version "1.12.0"

  if OS.mac?
    url "https://download.elastic.co/downloads/ecctl/1.12.0/ecctl_1.12.0_darwin_amd64.tar.gz", :using => CurlDownloadStrategy
    sha256 "597d2ffa3351f2216e64ea0526d7ff37831212ce307f2eb9c54010f82cac1735"
  elsif OS.linux?
    url "https://download.elastic.co/downloads/ecctl/1.12.0/ecctl_1.12.0_linux_amd64.tar.gz", :using => CurlDownloadStrategy
    sha256 "318ed2076e8ac4f168ab9a7c76450b9dbffce387ce0fdce1965cc1ced01752e2"
  end

  def install
    bin.install "ecctl"
    system "#{bin}/ecctl", "generate", "completions", "-l", "#{var}/ecctl.auto"
  end

  def caveats; <<~EOS
    To get autocompletions working make sure to run "source <(ecctl generate completions)".
    If you prefer to add to your shell interpreter configuration file run, for bash or zsh respectively:
    * `echo "source <(ecctl generate completions)" >> ~/.bash_profile`
    * `echo "source <(ecctl generate completions)" >> ~/.zshrc`.
  EOS
  end

  test do
    system "#{bin}/ecctl version"
  end
end
