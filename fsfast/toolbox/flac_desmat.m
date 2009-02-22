function flacnew = flac_desmat(flac,IRFOnly)
% flacnew = flac_desmat(flac,<IRFOnly>)
%
% Builds design matrices for each EV and performs the horizontal
% concatenation. Requires that flac.ntp and flac.ev(n).st already be
% set. If a nonpar is used, the matrix must already be set. These are
% done by flac_customize but could be done in some other way (allows
% for optseq-type optimization). If IRFOnly=1 and the FIR matrix
% exists, then the FIR matrix is not rebuilt (for speed).
%


%
% flac_desmat.m
%
% Original Author: Doug Greve
% CVS Revision Info:
%    $Author: greve $
%    $Date: 2009/02/22 21:41:42 $
%    $Revision: 1.16 $
%
% Copyright (C) 2002-2007,
% The General Hospital Corporation (Boston, MA). 
% All rights reserved.
%
% Distribution, usage and copying of this software is covered under the
% terms found in the License Agreement file named 'COPYING' found in the
% FreeSurfer source code root directory, and duplicated here:
% https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferOpenSourceLicense
%
% General inquiries: freesurfer@nmr.mgh.harvard.edu
% Bug reports: analysis-bugs@nmr.mgh.harvard.edu
%

flacnew = [];

if(nargin < 1 || nargin > 2)
 fprintf('flacnew = flac_desmat(flac,IRFOnly)\n');
 return;
end

if(nargin == 1) IRFOnly = 0; end

flacnew = flac;
flacnew.X = [];

nev = length(flac.ev);
for nthev = 1:nev
  ev = flac.ev(nthev);
  
  if(ev.ishrf)  
    % HRF Regressors
    st = ev.st; % Delay has already been added
    if(~isfield(ev,'Xfir')) ev.Xfir = []; end
    if(~IRFOnly | isempty(ev.Xfir))
      flacnew.ev(nthev).Xfir = fast_st2fir(st,flac.ntp,flac.TR,ev.psdwin,1,flac.fsv3_st2fir);
      if(isempty(flacnew.ev(nthev).Xfir)) 
	fprintf('ERROR: creating FIR design matrix for %s\n',...
		flacnew.ev(nthev).name);
	flacnew = [];
	return; 
      end
    end
    [Xirf tirf] = flac_ev2irf(flac,nthev);
    if(isempty(Xirf)) 
      fprintf('ERROR: creating IRF design matrix for %s\n',...
	      flacnew.ev(nthev).name);
      flacnew = [];
      return; 
    end
    flacnew.ev(nthev).Xirf = Xirf;
    flacnew.ev(nthev).tirf = tirf;
    flacnew.ev(nthev).X = flacnew.ev(nthev).Xfir * flacnew.ev(nthev).Xirf;
  else
    switch(ev.model)
     case {'baseline'}
      flacnew.ev(nthev).X = ones(flac.ntp,1);
     case {'polynomial'}
      polyorder = ev.params(1);
      X = fast_polytrendmtx(1,flac.ntp,1,polyorder);
      flacnew.ev(nthev).X = X(:,2:end);
     case {'fourier'}  
      period     = ev.params(1);
      nharmonics = ev.params(2);
      tdelay     = ev.params(3); % Need to add
      X = fast_fourier_reg(period,flac.ntp,flac.TR,nharmonics);
      flacnew.ev(nthev).X = X;
     case {'nyquist'}  
      X = 2*(rem([1:flac.ntp]',2)-.5);
      flacnew.ev(nthev).X = X;
     case {'asl'}  
      X = zeros(flac.ntp,1);
      X(1+ev.params(1):2:end) = 1;
      flacnew.ev(nthev).X = X;
     case {'aareg'}  
      nkeep = ev.params(1);
      fmax = ev.params(2);
      if(fmax < 0) fmax = 60/90; end % 90 beats per min
      fdelta = ev.params(3);
      if(fdelta < 0) fdelta = []; end % Use fftdelta
      X = fast_aareg(flac.ntp,flac.TR,fmax,fdelta);
      flacnew.ev(nthev).X = X(:,1:nkeep);
     case {'nonpar','selfregseg'}
      % Nonpar X must be already loaded with flac_customize.
      if(isempty(flacnew.ev(nthev).X))
	fprintf('ERROR: empty %s matrix for %s\n',ev.model,ev.name);
	flacnew = [];
	return;
      end
     case {'texclude'}  
      % texclude X must be already loaded with flac_customize,
      % OR it can also be empty.
     otherwise
      fprintf('ERROR: model %s unrecognized\n');
      flacnew = [];
      return;
    end
  end
  %keyboard
  
  flacnew.X = [flacnew.X flacnew.ev(nthev).X];
  
end % for ev

return;














