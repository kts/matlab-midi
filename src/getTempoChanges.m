function [tempos,tempos_time]=getTempoChanges(midi)
% [tempos,tempos_time]=getTempoChanges(midi)
%
% input: a midi struct from readmidi.m
% output:
%  tempos = tempo values indexed by tempos_time
%    tempos_time is in units of ticks
%
% should tempo changes effect across tracks? across channels?
%

% Copyright (c) 2009 Ken Schutte
% more info at: http://www.kenschutte.com/midi

tempos = [];
tempos_time = [];
for i=1:length(midi.track)
  cumtime=0;
  for j=1:length(midi.track(i).messages)
    cumtime = cumtime+midi.track(i).messages(j).deltatime;
%    if (strcmp(midi.track(i).messages(j).name,'Set Tempo'))
    if (midi.track(i).messages(j).midimeta==0 && midi.track(i).messages(j).type==81)
      tempos_time(end+1) = cumtime;
      d = midi.track(i).messages(j).data;
      tempos(end+1) =  d(1)*16^4 + d(2)*16^2 + d(3);
    end
  end
end

if numel(tempos)==0
    tempos = 500000; % default value for midi
    tempos_time = 0;
end



