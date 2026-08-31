#!/usr/bin/env perl

use strict;
use warnings;
use File::Find;

sub matching_delimiter {
  my ($source, $start, $open, $close) = @_;
  my $depth = 0;
  my $length = length($source);

  for (my $index = $start; $index < $length; $index++) {
    my $char = substr($source, $index, 1);
    my $next = $index + 1 < $length ? substr($source, $index + 1, 1) : "";

    if ($char eq '"' || $char eq "'" || $char eq '`') {
      my $quote = $char;
      for ($index++; $index < $length; $index++) {
        $char = substr($source, $index, 1);
        if ($char eq '\\') {
          $index++;
          next;
        }
        last if $char eq $quote;
      }
      next;
    }

    if ($char eq '/' && $next eq '/') {
      $index = index($source, "\n", $index + 2);
      return -1 if $index < 0;
      next;
    }

    if ($char eq '/' && $next eq '*') {
      $index = index($source, '*/', $index + 2);
      return -1 if $index < 0;
      $index++;
      next;
    }

    $depth++ if $char eq $open;
    if ($char eq $close) {
      $depth--;
      return $index if $depth == 0;
    }
  }

  return -1;
}

sub strip_event_calls {
  my ($source) = @_;

  while ($source =~ /^([ \t]*)trackEvent\s*\(/m) {
    my $start = $-[0];
    my $open = index($source, '(', $start);
    my $close = matching_delimiter($source, $open, '(', ')');
    die "Could not parse trackEvent call\n" if $close < 0;

    my $end = $close + 1;
    $end++ while substr($source, $end, 1) =~ /[ \t]/;
    $end++ if substr($source, $end, 1) eq ';';
    $end++ if substr($source, $end, 2) eq "\r\n";
    $end++ if substr($source, $end, 1) eq "\n";
    substr($source, $start, $end - $start, '');
  }

  return $source;
}

sub strip_action_metadata {
  my ($source) = @_;

  while ($source =~ /^([ \t]*)trackEvent\s*:/m) {
    my $start = $-[0];
    my $value = $+[0];
    $value++ while substr($source, $value, 1) =~ /[ \t]/;
    my $end;

    if (substr($source, $value, 1) eq '{') {
      my $close = matching_delimiter($source, $value, '{', '}');
      die "Could not parse trackEvent metadata\n" if $close < 0;
      $end = $close + 1;
    } elsif (substr($source, $value, 5) eq 'false') {
      $end = $value + 5;
    } else {
      die "Unexpected trackEvent metadata value\n";
    }

    $end++ while substr($source, $end, 1) =~ /[ \t]/;
    $end++ if substr($source, $end, 1) eq ',';
    $end++ if substr($source, $end, 2) eq "\r\n";
    $end++ if substr($source, $end, 1) eq "\n";
    substr($source, $start, $end - $start, '');
  }

  return $source;
}

sub strip_snapshot_metadata {
  my ($source) = @_;

  while ($source =~ /^([ \t]*)"trackEvent":\s*\{/m) {
    my $start = $-[0];
    my $open = index($source, '{', $start);
    my $close = matching_delimiter($source, $open, '{', '}');
    die "Could not parse trackEvent snapshot metadata\n" if $close < 0;
    my $end = $close + 1;
    $end++ while substr($source, $end, 1) =~ /[ \t]/;
    $end++ if substr($source, $end, 1) eq ',';
    $end++ if substr($source, $end, 2) eq "\r\n";
    $end++ if substr($source, $end, 1) eq "\n";
    substr($source, $start, $end - $start, '');
  }

  return $source;
}

my @files;
find(
  sub {
    return unless -f $_ && /\.(?:ts|tsx)$/;
    return if $File::Find::name =~ m{/(?:node_modules|dist|build|tests)/};
    push @files, $File::Find::name;
  },
  'excalidraw-app',
  'packages/excalidraw/actions',
  'packages/excalidraw/components',
);

for my $file (@files) {
  open my $input, '<', $file or die "Could not read $file: $!\n";
  local $/;
  my $source = <$input>;
  close $input;

  my $updated = $source;
  $updated =~ s/^\s*import \{ trackEvent \} from [^\n]+;\r?\n//mg;
  $updated = strip_event_calls($updated);
  if ($file =~ m{packages/excalidraw/actions/action}) {
    $updated = strip_action_metadata($updated);
  }

  next if $updated eq $source;
  open my $output, '>', $file or die "Could not write $file: $!\n";
  print {$output} $updated;
  close $output;
}

my $snapshot = 'packages/excalidraw/tests/__snapshots__/contextmenu.test.tsx.snap';
if (-f $snapshot) {
  open my $input, '<', $snapshot or die "Could not read $snapshot: $!\n";
  local $/;
  my $source = <$input>;
  close $input;
  my $updated = strip_snapshot_metadata($source);
  if ($updated ne $source) {
    open my $output, '>', $snapshot or die "Could not write $snapshot: $!\n";
    print {$output} $updated;
    close $output;
  }
}

for my $locale (glob('packages/excalidraw/locales/*.json')) {
  open my $input, '<', $locale or die "Could not read $locale: $!\n";
  my @lines = grep { $_ !~ /"trackedToSentry":/ } <$input>;
  close $input;
  open my $output, '>', $locale or die "Could not write $locale: $!\n";
  print {$output} @lines;
  close $output;
}
