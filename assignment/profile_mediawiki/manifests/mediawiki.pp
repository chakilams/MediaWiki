class profile_mediawiki::server (

$dirname = '/home/wiki',
$mediawiki_src = 'https://releases.wikimedia.org/mediawiki/1.33/mediawiki-1.33.0.tar.gz',

){

$filename = "${dirname}.tar.gz"
$install_path = "/home/wiki/${dirname}"

wget::fetch { "Download GPG Key":
  source      => 'https://releases.wikimedia.org/mediawiki/1.33/mediawiki-1.33.0.tar.gz.sig',
  destination => '/root/admin.pub',
  timeout     => 0,
  verbose     => false,
} ->

archive { $filename:
  path          => "/home/wiki/${filename}",
  source        => $mediawiki_src,
  extract       => true,
  extract_path  => '/home/wiki/',
  cleanup       => true,
}


}
