function irf_minvar_gui(x,column)
%IRF_MINVAR_GUI interactively do the minimum variance analysis
%
% IRF_MINVAR_GUI(X,COLUMN)
%  X - vector to use, [x(:,column(1)) x(:,column(2)) x(:,column(3))]
%  COLUMN - which columns to use, if not given use 2,3,4
%
% You can access the results through variable 'ud' that is defined as global
% ud.l - eigenvalues  ud.l(1), ud.l(2),ud.l(3)
% ud.v - eigenvectors (ud.v(1,:), ..), also ud.v1, ud.v2. ud.v3
% ud.Xminvar - data in minimum variance coordinates
%
% See also IRF_MINVAR
%
% $Id$

global ud
persistent tlim message t0;
%persistent ud tlim;

if isempty(message), % run only the first time during the session
    message='You can anytime access all the results from the variable "ud".';
    disp(message);
end

if      nargin < 1, help irf_minvar_gui;return;
elseif  (nargin==1 && ischar(x)), action=x;%disp(['action=' action]);
elseif  isnumeric(x),
    if size(x,2)<3, disp('Vector has too few components');return;end
    if nargin < 2,
        if size(x,2)==3, column=[1 2 3];end
        if size(x,2)>3, column=[2 3 4];end
    end
    action='initialize';
end

switch action,
    case 'initialize'
        % X is used for minimum variance estimates
        evalin('base','clear ud; global ud;');

        if min(column)==1, time_vector=1:size(x,1);
        elseif min(column)>1, time_vector=x(:,1);
        end

        X=[time_vector x(:,column)];X=irf_abs(X);
        ud={}; % structure to pass all information to manager function
        ud.X=X;
        ud.from = 1; % first click with mouse is 'from', second is 'to'
        ud.cancel = 0;
        tlim = [min(X(:,1)) max(X(:,1))];
        ud.tlim_mva=tlim+[-1 1]; % default tlim_mva includes all interval, add 1s to help later in program

        dgh=figure;clf;irf_figmenu;
        h(1)=subplot(4,1,1);
        set(h(1),'outerposition',[0 0.75 1 0.25]);
        irf_plot(h(1),X);axis tight;
        uf=get(gcf,'userdata');
        if isfield(uf,'t_start_epoch'), t0=uf.t_start_epoch;else t0=0; end
        set(dgh,    'windowbuttondownfcn', 'irf_minvar_gui(''ax'')');zoom off;
        
      %  irf_pl_info(h(1),['irf\_minvar\_gui() ' datestr(now)]); % add information to the plot
        set(h(1),'layer','top');
        grid(h(1),'on');
        ax=axis(h(1));
        ud.patch_mvar_intervals=patch([tlim(1) tlim(2) tlim(2) tlim(1)]-t0,[ax(3) ax(3) ax(4) ax(4)],[-1 -1 -1 -1],'y','parent',h(1));

        h(2)=subplot(4,1,2);set(h(2),'outerposition',[0 0.5 1 0.25]);
        irf_plot(h(2),X);
        axis(h(2),'tight'); 
        zoom(h(2),'off');

        h(3)=subplot(4,2,5);

        h(4)=subplot(4,2,6);

        ud.h=h;

        xp=0.2;yp=0.2;
        ud.fromtext=uicontrol('style', 'text', 'string', 'From:','units','normalized', 'position', [xp yp 0.1 0.04],'backgroundcolor','red');
        ud.fromh = uicontrol('style', 'edit', ...
            'string', irf_time(tlim(1),'iso'), ...
            'callback', 'irf_minvar_gui(''from'')', ...
            'backgroundcolor','white','units','normalized','position', [xp+0.11 yp 0.25 0.05]);

        yp=0.15;
        ud.totext=uicontrol('style', 'text', 'string', 'To:','units','normalized', 'position', [xp yp 0.1 0.04],'backgroundcolor','white');
        ud.toh=uicontrol('style', 'edit', ...
            'string', irf_time(tlim(2),'iso'), ...
            'callback', 'irf_minvar_gui(''from'')','backgroundcolor','white','units','normalized', 'position', [xp+0.11 yp 0.25 0.05]);


        xp=0.1;yp=0.1;
        uicontrol('style', 'text', 'string', 'Low pass filter f/Fs = ','units','normalized','position', [xp yp 0.2 0.04],'backgroundcolor','white');
        ud.filter = uicontrol('style', 'edit', ...
            'string', '1', ...
            'backgroundcolor','white','units','normalized','position', [xp+0.21 yp 0.1 0.05]);

        uimenu('label','&Recalculate','accelerator','r','callback','irf_minvar_gui(''mva'')');

        h(5)=subplot(4,2,8);
        axis(h(5),'off');
        irf_legend(0,['irf\_minvar\_gui() ' datestr(now)],[0.02 0.02],'fontsize',8); % add information to the plot
        ud.result_text=text(0,0.8,'result','parent',h(5));

        irf_minvar_gui('from');
        fix_legends;

    case 'ax'
        tlim = get(ud.patch_mvar_intervals, 'xdata'); tlim=tlim(:)';tlim(3:4)=[];
        uf=get(gcf,'userdata');
        if isfield(uf,'t_start_epoch'), t0=uf.t_start_epoch;else t0=0; end
        tlim=tlim+t0;
        p = get(gca, 'currentpoint')+t0;
        tlim_interval=get(gca,'xlim')+t0;
        if ud.from
            tlim(1) = max(tlim_interval(1), p(1));
            tlim(2) = max(p(1),tlim(2));
            set(ud.fromtext,'backgroundcolor','w');
            set(ud.totext,'backgroundcolor','r');
            ud.from = 0;
        else
            tlim(2) = min(tlim_interval(2), p(1));
            tlim(1) = min(tlim(1), p(1));
            set(ud.totext,'backgroundcolor','w');
            set(ud.fromtext,'backgroundcolor','r');
            ud.from = 1;
        end
        set(ud.fromh, 'string', epoch2iso(tlim(1),1));
        set(ud.toh, 'string', epoch2iso(tlim(2),1));
        set(ud.patch_mvar_intervals,'xdata',[tlim(1) tlim(2) tlim(2) tlim(1)]-t0);
        irf_minvar_gui('update_mva_axis');
    case 'from'
        tlim(1) = iso2epoch(get(ud.fromh,'string'));
        tlim(2) = iso2epoch(get(ud.toh,'string'));
        set(ud.patch_mvar_intervals,'xdata',[tlim(1) tlim(2) tlim(2) tlim(1)]-t0);
        irf_minvar_gui('update_mva_axis');
    case 'update_mva_axis'
        if tlim==ud.tlim_mva, % plot first time after 'mva'
            irf_plot(ud.h(2),ud.Xminvar);
            axis(ud.h(2),'fill');
            axis(ud.h(2),'tight');
            irf_timeaxis(ud.h(2),'date');
            plot(ud.h(3),ud.Xminvar(:,4),ud.Xminvar(:,2));
            xlabel(ud.h(3),'min');ylabel(ud.h(3),'max');
            axis(ud.h(3),'tight');
            axis(ud.h(3),'equal');
            grid(ud.h(3),'on');
            plot(ud.h(4),ud.Xminvar(:,3),ud.Xminvar(:,2));
            xlabel(ud.h(4),'interm');
            ylabel(ud.h(4),'max');
            axis(ud.h(4),'equal');
            grid(ud.h(4),'on');
        elseif (tlim(1)>=ud.tlim_mva(1) && tlim(2)<=ud.tlim_mva(2)) % zoom to something within tlim_mva
            irf_zoom(ud.h(2),'x',tlim);
        else                   % zoom to interval outside mva
            X=irf_tlim(ud.X,tlim);
            clear ud.Xminvar;
            ud.Xminvar=irf_newxyz(X,ud.v1,ud.v2,ud.v3);
            irf_plot(ud.h(2),ud.Xminvar);
            axis(ud.h(2),'tight');
            irf_timeaxis(ud.h(2),'date');
        end
        if (tlim(1)<ud.tlim_mva(1) || tlim(2)>ud.tlim_mva(2)) % if zooming outside tlim_mva mark mva interval
            set(ud.h(2),'layer','top');
            ax=axis(ud.h(2));
            grid(ud.h(2),'on');
            ud.mvar_interval_2nd=patch([ud.tlim_mva(1) ud.tlim_mva(2) ud.tlim_mva(2) ud.tlim_mva(1)],[ax(3) ax(3) ax(4) ax(4)],[-1 -1 -1 -1],'y','buttondownfcn', 'irf_minvar_gui(''ax'')','parent',ud.h(2));
        end
        fix_legends;
    case 'mva'
        ud.tlim_mva=tlim;
				X = ud.X;
				if eval(get(ud.filter,'string'))<1
					Fs = 1/(X(2,1)-X(1,1));
					flim = Fs*eval(get(ud.filter,'string'));
					X = irf_tlim(X, tlim + [-20/Fs 20/Fs]);
					X = irf_filt(X,0,flim,Fs,5);
				else
					if eval(get(ud.filter,'string'))>1, disp('f/Fs must be <1!!!'), end
					set(ud.filter,'string','1')
				end
        X = irf_tlim(X,tlim);
        clear ud.Xminvar;
        [ud.Xminvar, l, v]=irf_minvar(X);
        ud.l=l;ud.v=v;ud.v1=v(1,:);ud.v2=v(2,:);ud.v3=v(3,:);
        l_str=['L1=' num2str(l(1),3) ' L2=' num2str(l(2),3) ' L3=' num2str(l(3),3) '\newline'];
        lratio_str=['L1/L2=' num2str(l(1)/l(2),2) ' L2/L3=' num2str(l(2)/l(3),2) '\newline'];
        v1_str=['v1=[' num2str(v(1,:),'%6.2f') '] \newline'];
        v2_str=['v2=[' num2str(v(2,:),'%6.2f') '] \newline'];
        v3_str=['v3=[' num2str(v(3,:),'%6.2f') '] \newline'];
        v_str=[v1_str v2_str v3_str];
        set(ud.result_text,'string',[l_str lratio_str v_str],'verticalalignment','top');
        % disp(l_str);disp(lratio_str);disp(v1_str);disp(v2_str);disp(v3_str);
        irf_minvar_gui('update_mva_axis');
end

end


function fix_legends
global ud

switch size(ud.X,2)-1, % how many components
    case 3 %
        legend(ud.h(1),'x','y','z','Location','EastOutside');
        legend(ud.h(2),'max','interm','min','Location','EastOutside');
    case 4 %
        legend(ud.h(1),'x','y','z','abs','Location','EastOutside');
        legend(ud.h(2),'max','interm','min','abs','Location','EastOutside');
end
end
