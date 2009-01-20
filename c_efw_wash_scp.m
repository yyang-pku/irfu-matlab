function [res,resnan] = c_efw_wash_scp(data,method)
%C_EFW_WASH_SCP  Make SC Potential look prettier
%
% [RES,RESNAN] = C_EFW_WASH_SCP(DATA,[METHOD])
%
% METHOD of filling the gaps can be 
%           'PREVSPIN' - copy data from previous spin [default]
%           'LINEAR'   - linear interpolation through the gap
% $Id$

% ----------------------------------------------------------------------------
% "THE BEER-WARE LICENSE" (Revision 42):
% <yuri@irfu.se> wrote this file.  As long as you retain this notice you
% can do whatever you want with this stuff. If we meet some day, and you think
% this stuff is worth it, you can buy me a beer in return.   Yuri Khotyaintsev
% ----------------------------------------------------------------------------

if nargin < 2, method = 'prevspin'; end
	

res = data;
jj = [];
ii = find( isnan(data(:,2)) );

% Fill gaps before spectral cleaning
if ~isempty(ii)
	if length(ii) == size(data,1), return, end
	
	% First point is already a gap
	if ii(1) == 1
		jj = find(~isnan(data(:,2)));
		res(1:jj(1)-1,2) = res(jj(1),2);
		ii(1:jj(1)-1) = [];
	end
end

% Data ends by a gap
if ~isempty(ii) && ii(end) == size(data,1)
	if isempty(jj), jj = find(~isnan(data(:,2))); end
	res(jj(end)+1:end,2) = res(jj(end),2);
	ii(jj(end)+1:end) = [];
end

if ~isempty(ii)
	ju = find(diff(ii)-1);
	begs = [ii(1)-1; ii(ju+1)-1];
	ends = [ii(ju)+1; ii(end)+1];
	switch lower(method)
		case 'linear'
			for idx=1:length(begs);
				res(begs(idx)+1:ends(idx)-1,2) = interp1(...
					[res(begs(idx),1); res(ends(idx),1)],...
					[res(begs(idx),2); res(ends(idx),2)],...
					res(begs(idx)+1:ends(idx)-1,1),'linear');
			end
		case 'prevspin'
			for idx=1:length(begs);
				prevs = res( res(:,1) >= res(begs(idx)+1,1)-4 , :);
				res(begs(idx)+1:ends(idx)-1,2) = ...
					prevs( 1:ends(idx)-begs(idx)-1 , 2);
			end
		otherwise
			error('MTHOD can be : LINEAR, PREVSPIN')
	end
			
end

res = clean_spec(res,4,0.75);
res = clean_spec(res,4,0.2);
res = clean_spec(res,4,0.2);

resnan = res;
resnan(isnan(data(:,2)),2) = NaN;

function res = clean_spec(res,k1,k2)

m = mean(res(:,2));
if isnan(m), error('data still contains NaNs'), end
f = fft(res(:,2) - m);
nff = length(f);
if(rem(nff,2)==0), kfft=nff/2 +1;
else kfft=(nff+1)/2;
end
freq = c_efw_fsample(res)*(1:(kfft-1))'/nff;
a = abs(f(1:kfft-1));
clf,plot(freq,a,'k.-'), hold on
cls = 'brgmkbrgm';
for n = 1:8
	fref = .25 * n;
	ip = find(freq>fref*4/5 & freq<fref*3/2); lip8 = fix(length(ip)/8);
	iiii = find( a > mean(a(ip))+(k1+(n-1)*k2)*std(a(ip)) );
	iiii = iiii( iiii>ip(1)+lip8 & iiii<ip(end)-lip8);
	plot(freq(iiii),a(iiii),[cls(n) '*'])
	f(iiii) = mean(f(ip));
end
hold off
res(:,2) = ifft(f,'symmetric') + m;



	
	