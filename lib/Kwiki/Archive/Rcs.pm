package Kwiki::Archive::Rcs;
use strict;
use warnings;
use Kwiki::Archive '-Base';
our $VERSION = '0.11';

sub file_path {
    my $page_id = shift;
    $self->plugin_directory . '/' . $page_id . ',v';
}

sub commit {
    my $page = shift;
    my $props = $self->page_properties($page);
    my $rcs_file_path = $self->file_path($page->id);
    if (not -f $rcs_file_path) {
        $self->shell("rcs -q -i $rcs_file_path < /dev/null");
    }

    my $msg = join ',',
      $self->uri_escape($props->{edit_by}),
      $props->{edit_time},
      $props->{edit_unixtime};

    my $page_file_path = $page->io;
    $self->shell(qq{ci -q -l -m"$msg" $page_file_path $rcs_file_path});
}

sub revision_numbers {
    my $page = shift;
    [map $_->{revision_id}, @{$self->history($page)}];
}

sub fetch_metadata {
    my $page = shift;
    my $rev = shift;
    my $rcs_file_path = $self->file_path($page->id);
    my $rlog = io("rlog -zLT -r $rev $rcs_file_path |") or die $!; 
    $rlog->utf8 if $self->use_utf8;
    $self->parse_metadata($rlog->all);
}

sub parse_metadata {
    my $log = shift;
    $log =~ /
        ^revision\s+(\S+).*?
        ^date:\s+(.+?);.*?\n
        (.*)
    /xms or die "Couldn't parse rlog:\n$log";

    my $revision_id = $1;
    my $msg = $3;
    chomp $msg;

    my ($edit_by, $edit_time, $edit_unixtime) = split ',', $msg;
    $edit_time ||= $2;
    $edit_unixtime ||= 0;
    $revision_id =~ s/^1\.//;

    return {
        revision_id => $revision_id,
        edit_by => $self->uri_unescape($edit_by),
        edit_time => $edit_time,
        edit_unixtime => $edit_unixtime,
    };
}

sub history {
    my $page = shift;
    my $rcs_file_path = $self->file_path($page->id);
    my $rlog = io("rlog -zLT $rcs_file_path |") or die $!; 
    $rlog->utf8 if $self->use_utf8;

    my $input = $rlog->all;
    $input =~ s/
        \n=+$
        .*\Z
    //msx;
    my @rlog = split /^-+\n/m, $input;
    shift(@rlog);

    return [
        map $self->parse_metadata($_), @rlog
    ];
}

sub fetch {
    my $page = shift;
    my $revision_id = shift;
    my $revision = "1.$revision_id";
    my $rcs_file_path = $self->file_path($page->id);
    local($/, *CO);
    open CO, qq{co -q -p$revision $rcs_file_path |}
      or die $!;
    binmode(CO, ':utf8') if $self->use_utf8;
    scalar <CO>;
}

sub shell {
    my ($command) = @_;
    use Cwd;
    $! = undef;
    system($command) == 0 
      or die "$command failed:\n$?\nin " . Cwd::cwd();
}

1;

__DATA__

=head1 NAME 

Kwiki::Archive::Rcs - Kwiki Page Archival Using RCS

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Brian Ingerson <INGY@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2004. Brian Ingerson. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
