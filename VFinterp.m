function [ZI]=VFinterp(X,Y,Z,XI,YI,M)
% --- Velocity Interpolation Subfunction

%find grid sizes
Method={'nearest','linear','cubic'};

% keyboard
F = griddedInterpolant(Y,X,Z,Method{M},'nearest');
% F = griddedInterpolant({Y(:,1),X(1,:)},Z,Method(M),'nearest');
ZI = F(YI,XI);

% this is the rest of the old VFInterp, which sometimes had problems with the 
% way the nearest neighbor algorithm was programmed.  It assumed too much.
%{
L=[max(max(YI)) max(max(XI))];
S=size(X);

%buffer matrix with nearest neighbor approximation for image boundaries
Xf = [1 X(1,:) L(2); ones(S(1),1) X L(2)*ones(S(1),1); 1 X(1,:) L(2);];
Yf = [ones(1,S(2)+2); Y(:,1) Y Y(:,1); L(1)*ones(1,S(2)+2)];
Zf = zeros(S+2);
Zf(2:end-1,2:end-1)=Z;
Zf(1,2:end-1)   = (Z(1,:)-Z(2,:))./(Y(1,:)-Y(2,:)).*(1-Y(2,:))+Z(1,:);
Zf(end,2:end-1) = (Z(end,:)-Z(end-1,:))./(Y(end,:)-Y(end-1,:)).*(L(1)-Y(end-1,:))+Z(end,:);
Zf(2:end-1,1)   = (Z(:,1)-Z(:,2))./(X(:,1)-X(:,2)).*(1-X(:,2))+Z(:,1);
Zf(2:end-1,end) = (Z(:,end)-Z(:,end-1))./(X(:,end)-X(:,end-1)).*(L(2)-X(:,end-1))+Z(:,end);
Zf(1,1)     = mean([Zf(2,1) Zf(1,2)]);
Zf(end,1)   = mean([Zf(end-1,1) Zf(end,2)]);
Zf(1,end)   = mean([Zf(2,end) Zf(1,end-1)]);
Zf(end,end) = mean([Zf(end-1,end) Zf(end,end-1)]);

%velocity interpolation
Zf(isnan(Zf))=0;
keyboard
ZI=interp2(Xf,Yf,Zf,XI,YI,char(Method(M)));
%}

end