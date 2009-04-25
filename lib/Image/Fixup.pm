package Image::Fixup;
use strict;
use warnings;
use vars qw/$VERSION/;

use base qw/Class::Light/;

use Carp;
use Image::ExifTool;
use Image::Magick;

$VERSION = '0.01000';

my %exif2im = (
	'Horizontal (normal)' => 'top-left',
	'Mirror horizontal' => 'top-right',
	'Rotate 180' => 'bottom-right',
	'Mirror vertical' => 'bottom-left',
	'Mirror horizontal and rotate 270 CW' => 'left-top',
	'Rotate 90 CW' => 'right-top',
	'Mirror horizontal and rotate 90 CW' => 'right-bottom',
	'Rotate 270 CW' => 'left-bottom'
);

my %im2exif = reverse %exif2im;

sub _init {
	my $self   = shift;
	my $path   = shift;
	my $prefix = defined $_[0] ? shift : 'fixed_';
	my $image  = Image::Magick->new;
	my $exif   = Image::ExifTool->new;
	my ($base, $file) = ($path =~ /(.*)\/(.*)/);
	$base = $path unless $base;
	$file = $base unless $file;

	my $err = $image->Read($path);
	warn $err if $err;
	$exif->ExtractInfo($path);

	my %attr = (
		image => $image,
		exif => $exif,
		filename => $path,
		outfile  => $prefix . $file,
		filesize => $image->Get('filesize'), # in bytes
		orientation => __PACKAGE__->convertOrientation($exif->GetValue('Orientation')),
		height => $image->Get('height'),
		width => $image->Get('width')
	);

	$self->{$_} = $attr{$_} for keys %attr;
}

sub convertOrientation {
	my $self   = shift;
	my $orient = shift;
	if (exists $exif2im{$orient}) {
		return $exif2im{$orient};
	} elsif (exists $im2exif{$orient}) {
		return $im2exif{$orient};
	}
	croak "Unknown orientation $orient";
}

sub autoOrient {
	my $self  = shift;
	my $image = $self->getImage;
	my $exif  = $self->getExif;
	$image->AutoOrient;
	$exif->SetNewValue('Orientation','Horizontal (normal)');
	$self->{orientation} = 'top-left';
	$self->updateInfo;
}

# Currently just halves the size of the image. A better algorithm (but more
# resource intensive) would continually reduce the image size and check the
# resulting file size until the file size is below a specified limit.
sub autoResize {
	my $self  = shift;
	my $image = $self->getImage;
	$image->Resize(
		width  => int($image->Get('width') / 2),
		height => int($image->Get('height') / 2)
	);
	$self->updateInfo;
}

sub updateInfo {
	my $self  = shift;
	my $image = $self->getImage;
	$self->{height} = $image->Get('height');
	$self->{width} = $image->Get('width');
	$self->{filesize} = $image->Get('filesize');
}

sub writeImage {
	my $self  = shift;
	my $image = $self->getImage;
	my $exif  = $self->getExif;
	my $out   = $self->getOutfile;
	$DB::single = 1;
	$image->Write(filename => $out);
	$exif->WriteInfo($out);
	$self->_init($out,'');
}

sub setOrientation {
	my $self = shift;
	my $orient = shift;
	$self->getImage->Set(orientation => $orient);
	$self->{orientation} = $orient;
}

sub printImageInfo {
	my $self = shift;
	print 'filename: ' . $self->getFilename . "\n";
	print 'orientation: ' . $self->getOrientation . "\n";
	print 'width: ' . $self->getWidth . "\n";
	print 'height: ' . $self->getHeight . "\n";
	print 'filesize: ' . $self->getFilesize . "\n";
}

1;
