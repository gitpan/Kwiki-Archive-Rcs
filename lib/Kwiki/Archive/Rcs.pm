package Kwiki::Archive::Rcs;
use strict;
use warnings;
use Kwiki::Archive '-Base';
our $VERSION = '0.10';

field 'user_name';

sub register {
    my $registry = shift;
    $registry->add(page_store_hook => 'commit');
}

sub file_path {
    my $page_id = shift;
    $self->plugin_directory . '/' . $self->uri_escape($page_id) . ',v';
}

sub init {
    $self->use_class('pages');
    $self->generate 
      unless @{[io($self->plugin_directory)->all]} > 0;
}

sub generate {
    my $dir = $self->plugin_directory;
    umask 0000;
    chmod 0777, $dir;
    $self->user_name('kwiki-install');
    for my $page ($self->pages->all) {
        $self->commit($page);
    }
}
    
sub commit {
    my $page = shift;
    my $rcs_file_path = $self->file_path($page->id);
    if (not -f $rcs_file_path) {
        $self->shell("rcs -q -i $rcs_file_path < /dev/null");
    }
    my $time = time;
    my $msg = join ',',
      $self->uri_escape($self->user_name || $page->metadata->edit_by),
      ($page->metadata->edit_time || scalar(gmtime($time))),
      ($page->metadata->edit_unixtime || $time),
      ;

    my $page_file_path = $page->database_directory . '/' . $page->id;
    $self->shell(qq{ci -q -l -m"$msg" $page_file_path $rcs_file_path});
}

sub history {
    my $page = shift;
    my $page_id = $page->id;
    my $rcs_file_path = $self->file_path($page_id);
    open RLOG, "rlog -zLT $rcs_file_path |"
      or DIE $!; 
    binmode(RLOG, ':utf8') if $self->use_utf8;
    my $input;
    {
        local $/;
        $input = <RLOG>;
    }
    close RLOG;
    (my $rlog = $input) =~ s/\n=+$.*\Z//ms;
    my @rlog = split /^-+\n/m, $rlog;
    shift(@rlog);
    my $history = [];
    for (@rlog) {
        /^revision\s+(\S+).*?
         ^date:\s+(.+?);.*?\n
         (.*)
        /xms or die "Couldn't parse rlog for '$page_id':\n$rlog";
        my $revision_id = $1;
        my $msg = $3;
        chomp $msg;
        my ($edit_by, $edit_time, $edit_unixtime) = split ',', $msg;
        $edit_time ||= $2;
        $edit_unixtime ||= 0;
        $revision_id =~ s/^1\.//;
        push @$history,
          {
            revision_id => $revision_id,
            edit_by => $self->uri_unescape($edit_by),
            edit_time => $edit_time,
            edit_unixtime => $edit_unixtime,
          };
    }
    return $history;
}

sub revision_number {
    $self->history(shift)->[0]->{revision_id} || 0;    
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
