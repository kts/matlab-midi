function [PR,t,nn] = piano_roll(Notes,vel,ts)
%
% Inputs:
%  Notes: A 'notes' matrix as returned from midiInfo.m
%  vel:   (optional) if vel==1, set value to note velocity instead of 1. (default 0)
%  ts:    (optional) time step of one 'pixel' in seconds (default 0.01)
%
% Outputs:
%  PR:    PR(ni,ti): value at note index ni, time index ti
%  t:     t(ti):  time value in seconds at time index ti
%  nn:    nn(ni): note number at note index ti
%
%   (i.e. t and nn provide 'real-world units' for PR)
%

% Copyright (c) 2009 Ken Schutte
% more info at: http://www.kenschutte.com/midi

if nargin < 2
  vel = 0;
end
if nargin < 3
  ts = 0.01;
end

Nnotes = size(Notes,1);

n1 = round(Notes(:,5)/ts)+1; % start tics
n2 = round(Notes(:,6)/ts)+1; % end tics

if vel == 0
  vals = ones(Nnotes,1);
else
  vals = Notes(:,4); % velocity
end

Notes(:,3) = Notes(:,3) + (Notes(:,3)==0); % correct zeros in the tone
PR = zeros(max(Notes(:,3)), max(n2));

for i=1:Nnotes
  PR(Notes(i,3), n1(i):n2(i)) = vals(i);
end

% create quantized time axis:
t = linspace(0,max(Notes(:,6)),size(PR,2));
% note axis:
nn = min(Notes(:,3)):max(Notes(:,3));
% truncate to notes used:
PR = PR(nn,:);
