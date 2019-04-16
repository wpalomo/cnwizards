{******************************************************************************}
{                       CnPack For Delphi/C++Builder                           }
{                     �й����Լ��Ŀ���Դ�������������                         }
{                   (C)Copyright 2001-2019 CnPack ������                       }
{                   ------------------------------------                       }
{                                                                              }
{            ���������ǿ�Դ���������������������� CnPack �ķ���Э������        }
{        �ĺ����·�����һ����                                                }
{                                                                              }
{            ������һ��������Ŀ����ϣ�������ã���û���κε���������û��        }
{        �ʺ��ض�Ŀ�Ķ������ĵ���������ϸ���������� CnPack ����Э�顣        }
{                                                                              }
{            ��Ӧ���Ѿ��Ϳ�����һ���յ�һ�� CnPack ����Э��ĸ��������        }
{        ��û�У��ɷ������ǵ���վ��                                            }
{                                                                              }
{            ��վ��ַ��http://www.cnpack.org                                   }
{            �����ʼ���master@cnpack.org                                       }
{                                                                              }
{******************************************************************************}

unit CnVclToFmxMap;
{* |<PRE>
================================================================================
* �������ƣ�CnPack IDE ר�Ұ�
* ��Ԫ���ƣ�CnWizards VCL/FMX ת����Ԫ
* ��Ԫ���ߣ���Х (liuxiao@cnpack.org)
* ��    ע���õ�Ԫ�� Delphi 10.3.1 �� VCL �� FMX Ϊ����ȷ����һЩӳ���ϵ
* ����ƽ̨��PWin7 + Delphi 10.3.1
* ���ݲ��ԣ�XE2 �����ϣ���֧�ָ��Ͱ汾
* �� �� �����õ�Ԫ�е��ַ��������ϱ��ػ�������ʽ
* �޸ļ�¼��2019.04.10 V1.0
*               ������Ԫ��ʵ�ֻ�������
================================================================================
|</PRE>}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  TCnPropertyConverter = class(TObject)
  {* ת��ĳЩ�ض����ԵĻ���}
  public
    class procedure GetProperties(OutProperties: TStrings); virtual;
    class procedure ProcessProperties(const PropertyName, TheClassName,
      PropertyValue: string; InProperties, OutProperties: TStrings; Tab: Integer = 0); virtual;
    {* ����ָ�����ԡ����ͬʱ�������������ԣ�Ҫɾ������������}
  end;

  TCnPropertyConverterClass = class of TCnPropertyConverter;

function CnConvertPropertiesFromVclToFmx(const InComponentClass, InContainerClass: string;
  var OutComponentClass: string; InProperties, OutProperties, OutEventsIntf,
  OutEventsImpl: TStrings; IsContainer: Boolean; Tab: Integer = 0): Boolean;
{* ��һ�� VCL ��������԰����¼�ת���� FMX �������¼����룬���سɹ����}

function CnGetFmxUnitNameFromClass(const ComponentClass: string): string;
{* ���� FMX ������ڵĵ�Ԫ��}

function CnGetFmxClassFromVclClass(const ComponentClass: string): string;
{* ���� VCL ���������Ӧ�� FMX �������}

function CnIsVclEnumPropertyNeedConvert(const PropertyName: string): Boolean;
{* �ж�ĳ VCL ������������ֵ�Ƿ���Ҫת��}

function CnConvertEnumValue(const PropertyValue: string): string;
{* ת��ö�ٳ���ֵ}

procedure RegisterCnPropertyConverter(AClass: TCnPropertyConverterClass);
{* �����ע���ض����Ƶ����Ե�ת����}

function GetFloatStringFromInteger(IntValue: Integer): string;

implementation

type
  TCnContainerConverter = class(TCnPropertyConverter)
  {* ת�������������ת����ʵ���࣬�����ָ�����ã�����ע��}
  public
    class procedure GetProperties(OutProperties: TStrings); override;
    class procedure ProcessProperties(const PropertyName, TheClassName,
      PropertyValue: string; InProperties, OutProperties: TStrings;
      Tab: Integer = 0); override;
  end;

var
  FConverterClasses: TList<TCnPropertyConverterClass> = nil;
  {* �洢��������ת���������ע��}

  FVclPropertyConverterMap: TDictionary<string, TCnPropertyConverterClass> = nil;
  {* �洢���������������ת�����Ĺ�ϵ}

  FVclFmxClassMap: TDictionary<string, string> = nil;
  {* �洢 VCL ���� FMX ��Ķ�Ӧת����ϵ}

  FFmxClassUnitMap: TDictionary<string, string> = nil;
  {* �洢 FMX ������������Ԫ�Ķ�Ӧ��ϵ}

  FFmxEventDeclMap: TDictionary<string, string> = nil;
  {* �洢 FMX ���ظ����¼������������Ķ�Ӧ��ϵ�������ظ��Ĳ��ڴ���}

  FVclFmxPropNameMap: TDictionary<string, string> = nil;
  {* �洢 VCL �������� FMX ���Զ�Ӧ��ϵ������Ҫ����ͬ}

  FVclFmxEnumMap: TDictionary<string, string> = nil;
  {* �洢ͬ�����Ե�ֵ�ǲ�ͬ���ֵ�ö�����͵Ķ�Ӧ��ϵ}

const
  // VCL �� FMX ����Ķ�Ӧת����ϵ��ͬ������
  VCL_FMX_CLASS_PAIRS: array[0..42] of string = (
    'TButton:TButton',        // ���������
    'TCalendar:TCalendar',
    'TCheckBox:TCheckBox',
    'TColorBox:TColorBox',
    'TColorListBox:TColorListBox',
    'TComboBox:TComboBox',
    'TEdit:TEdit',
    'TGroupBox:TGroupBox',
    'THeader:THeader',
    'TImage:TImage',
    'TLabel:TLabel',
    'TListBox:TListBox',
    'TListView:TListView',
    'TMemo:TMemo',
    'TPageControl:TTabControl',  // �����ͬ
    'TTabSheet:TTabItem',
    'TPaintBox:TPaintBox',
    'TPanel:TPanel',
    'TProgressBar:TProgressBar',
    'TRadioButton:TRadioButton',
    'TScrollBar:TScrollBar',
    'TScrollBox:TScrollBox',
    'TSpeedButton:TSpeedButton',
    'TSplitter:TSplitter',
    'TStatusBar:TStatusBar',
    'TStringGrid:TStringGrid',
    'TToolbar:TToolbar',
    'TTrackBar:TTrackBar',
    'TTreeView:TTreeView',
    'TAction:TAction',         // �����������
    'TActionList:TActionList',
    'TGestureManager:TGestureManager',
    'TImageList:TImageList',
    'TMainMenu:TMainMenu',
    'TMenuItem:TMenuITem',
    'TMediaPlayer:TMediaPlayer',
    'TOpenDialog:TOpenDialog',
    'TPageSetupDialog:TPageSetupDialog',
    'TPopupMenu:TPopupMenu',
    'TPrinterSetupDialog:TPrinterSetupDialog',
    'TSaveDialog:TSaveDialog',
    'TTimer:TTimer',
    'TWindowStore:TWindowStore'
  );

  // FMX ����������ڵ�Ԫ�Ķ�Ӧ��ϵ�����ڶ�Ӧ Pas ����
  FMX_CLASS_UNIT_PAIRS: array[0..228] of string = (
    'TActiveMaskedImage:FMX.Styles.Objects',        // ���������
    'TActiveOpacityObject:FMX.Styles.Objects',
    'TActiveStyleObject:FMX.Styles.Objects',
    'TActiveStyleTextObject:FMX.Styles.Objects',
    'TAlphaTrackBar:FMX.Colors',
    'TAniIndicator:FMX.StdCtrls',
    'TArc:FMX.Objects',
    'TArcDial:FMX.StdCtrls',
    'TBannerAd:FMX.Advertising',
    'TButton:FMX.StdCtrls',
    'TButtonStyleObject:FMX.Styles.Objects',
    'TButtonStyleTextObject:FMX.Styles.Objects',
    'TBWTrackBar:FMX.Colors',
    'TCalendar:FMX.Calendar',
    'TCalloutPanel:FMX.StdCtrls',
    'TCalloutRectangle:FMX.Objects',
    'TCheckBox:FMX.StdCtrls',
    'TCheckStyleObject:FMX.Styles.Objects',
    'TCircle:FMX.Objects',
    'TColorBox:FMX.Colors',
    'TColorButton:FMX.Colors',
    'TColorComboBox:FMX.Colors',
    'TColorListBox:FMX.Colors',
    'TColorPanel:FMX.Colors',
    'TColorPicker:FMX.Colors',
    'TColorQuad:FMX.Colors',
    'TComboBox:FMX.ListBox',
    'TComboColorBox:FMX.Colors',
    'TComboEdit:FMX.ComboEdit',
    'TComboTrackBar:FMX.ComboTrackBar',
    'TCornerButton:FMX.StdCtrls',
    'TDateEdit:FMX.DateTimeCtrls',
    'TDropTarget:FMX.ExtCtrls',
    'TEdit:FMX.Edit',
    'TEllipse:FMX.Objects',
    'TExpander:FMX.StdCtrls',
    'TFlowLayout:FMX.Layouts',
    'TFlowLayoutBreak:FMX.Layouts',
    'TFramedScrollBox:FMX.Layouts',
    'TFramedVertScrollBox:FMX.Layouts',
    'TGlyph:FMX.ImgList',
    'TGradientEdit:FMX.Colors',
    'TGrid:FMX.Grid',
    'TGridLayout:FMX.Layouts',
    'TGridPanelLayout:FMX.Layouts',
    'TGroupBox:FMX.StdCtrls',
    'THeader:FMX.Header',
    'THorzScrollBox:FMX.Layouts',
    'THueTrackBar:FMX.Colors',
    'TImage:FMX.Objects',
    'TImageControl:FMX.StdCtrls',
    'TImageViewer:FMX.ExtCtrls',
    'TLabel:FMX.StdCtrls',
    'TLayout:FMX.Layouts',
    'TLine:FMX.Objects',
    'TListBox:FMX.ListBox',
    'TListView:FMX.ListView',
    'TMagnifierGlass:FMX.MagnifierGlass',
    'TMapView:FMX.Maps',
    'TMaskedImage:FMX.Styles.Objects',
    'TMediaPlayerControl:FMX.Media',
    'TMemo:FMX.Memo',
    'TMenuBar:FMX.Menus',
    'TMultiView:FMX.MultiView',
    'TNumberBox:FMX.NumberBox',
    'TPaintBox:FMX.Objects',
    'TPanel:FMX.StdCtrls',
    'TPath:FMX.Objects',
    'TPathLabel:FMX.StdCtrls',
    'TPie:FMX.Objects',
    'TPlotGrid:FMX.ExtCtrls',
    'TPopup:FMX.Controls',
    'TPopupBox:FMX.ExtCtrls',
    'TPresentedScrollBox:FMX.ScrollBox',
    'TProgressBar:FMX.StdCtrls',
    'TRadioButton:FMX.StdCtrls',
    'TRectangle:FMX.Objects',
    'TRoundRect:FMX.Objects',
    'TScaledLayout:FMX.Layouts',
    'TScrollBar:FMX.StdCtrls',
    'TScrollBox:FMX.Layouts',
    'TSelection:FMX.Objects',
    'TSelectionPoint:FMX.Objects',
    'TSizeGrip:FMX.StdCtrls',
    'TSmallScrollBar:FMX.StdCtrls',
    'TSpeedButton:FMX.StdCtrls',
    'TSpinBox:FMX.SpinBox',
    'TSplitter:FMX.StdCtrls',
    'TStatusBar:FMX.StdCtrls',
    'TStringGrid:FMX.Grid',
    'TStyleObject:FMX.Styles.Objects',
    'TStyleTextObject:FMX.Styles.Objects',
    'TSwitch:FMX.StdCtrls',
    'TSystemButtonObject:FMX.Styles.Objects',
    'TTabControl:FMX.TabControl',
    'TTabStyleObject:FMX.Styles.Objects',
    'TTabStyleTextObject:FMX.Styles.Objects',
    'TText:FMX.Objects',
    'TTimeEdit:FMX.DateTimeCtrls',
    'TTintedButtonStyleObject:FMX.Styles.Objects',
    'TTintedStyleObject:FMX.Styles.Objects',
    'TToolBar:FMX.StdCtrls',
    'TTrackBar:FMX.StdCtrls',
    'TTreeView:FMX.TreeView',
    'TVertScrollBox:FMX.Layouts',
    'TViewport3D:FMX.Viewport3D',
    'TWebBrowser:FMX.WebBrowser',
    'TActionList:FMX.ActnList',         // �����������
    'TAddressBook:FMX.AddressBook',
    'TAffineTransformEffect:FMX.Filter.Effects',
    'TAppAnalytics:FMX.Analytics.AppAnalytics',
    'TBandedSwirlEffect:FMX.Filter.Effects',
    'TBandedSwirlTransitionEffect:FMX.Filter.Effects',
    'TBandsEffect:FMX.Filter.Effects',
    'TBevelEffect:FMX.Effects',
    'TBitmapAnimation:FMX.Ani',
    'TBitmapListAnimation:FMX.Ani',
    'TBlindTransitionEffect:FMX.Filter.Effects',
    'TBloodTransitionEffect:FMX.Filter.Effects',
    'TBloomEffect:FMX.Filter.Effects',
    'TBlurEffect:FMX.Effects',
    'TBlurTransitionEffect:FMX.Filter.Effects',
    'TBoxBlurEffect:FMX.Filter.Effects',
    'TBrightTransitionEffect:FMX.Filter.Effects',
    'TBufferLayer3D:FMX.Layers3D',
    'TCamera:FMX.Controls3D',
    'TCameraComponent:FMX.Media',
    'TCircleTransitionEffect:FMX.Filter.Effects',
    'TColorAnimation:FMX.Ani',
    'TColorKeyAlphaEffect:FMX.Filter.Effects',
    'TColorKeyAnimation:FMX.Ani',
    'TColorMaterialSource:FMX.MaterialSources',
    'TCone:FMX.Objects3D',
    'TContrastEffect:FMX.Filter.Effects',
    'TCropEffect:FMX.Filter.Effects',
    'TCrumpleTransitionEffect:FMX.Filter.Effects',
    'TCube:FMX.Objects3D',
    'TCylinder:FMX.Objects3D',
    'TDirectionalBlurEffect:FMX.Filter.Effects',
    'TDisk:FMX.Objects3D',
    'TDissolveTransitionEffect:FMX.Filter.Effects',
    'TDropTransitionEffect:FMX.Filter.Effects',
    'TDummy:FMX.Objects3D',
    'TEllipse3D:FMX.Objects3D',
    'TEmbossEffect:FMX.Filter.Effects',
    'TFadeTransitionEffect:FMX.Filter.Effects',
    'TFillEffect:FMX.Filter.Effects',
    'TFillRGBEffect:FMX.Filter.Effects',
    'TFloatAnimation:FMX.Ani',
    'TFloatKeyAnimation:FMX.Ani',
    'TGaussianBlurEffect:FMX.Filter.Effects',
    'TGestureManager:FMX.Gestures',
    'TGloomEffect:FMX.Filter.Effects',
    'TGlowEffect:FMX.Effects',
    'TGradientAnimation:FMX.Ani',
    'TGrid3D:FMX.Objects3D',
    'THueAdjustEffect:FMX.Filter.Effects',
    'TImage3D:FMX.Layers3D',
    'TImageList:FMX.ImgList',
    'TInAppPurchase:FMX.InAppPurchase',
    'TInnerGlowEffect:FMX.Effects',
    'TInvertEffect:FMX.Filter.Effects',
    'TLang:FMX.Types',
    'TLayer3D:FMX.Layers3D',
    'TLayout3D:FMX.Layers3D',
    'TLight:FMX.Controls3D',
    'TLightMaterialSource:FMX.MaterialSources',
    'TLineTransitionEffect:FMX.Filter.Effects',
    'TMagnifyEffect:FMX.Filter.Effects',
    'TMagnifyTransitionEffect:FMX.Filter.Effects',
    'TMainMenu:FMX.Menus',
    'TMaskToAlphaEffect:FMX.Filter.Effects',
    'TMediaPlayer:FMX.Media',
    'TMesh:FMX.Objects3D',
    'TModel3D:FMX.Objects3D',
    'TMonochromeEffect:FMX.Filter.Effects',
    'TNormalBlendEffect:FMX.Filter.Effects',
    'TOpenDialog:FMX.Dialogs',
    'TPageSetupDialog:FMX.Printer',
    'TPaperSketchEffect:FMX.Filter.Effects',
    'TPath3D:FMX.Objects3D',
    'TPathAnimation:FMX.Controls',
    'TPencilStrokeEffect:FMX.Filter.Effects',
    'TPerspectiveTransformEffect:FMX.Filter.Effects',
    'TPinchEffect:FMX.Filter.Effects',
    'TPixelateEffect:FMX.Filter.Effects',
    'TPixelateTransitionEffect:FMX.Filter.Effects',
    'TPlane:FMX.Objects3D',
    'TPopupMenu:FMX.Menus',
    'TPrintDialog:FMX.Printer',
    'TPrinterSetupDialog:FMX.Printer',
    'TProxyObject:FMX.Controls3D',
    'TRadialBlurEffect:FMX.Filter.Effects',
    'TRasterEffect:FMX.Effects',
    'TRectangle3D:FMX.Objects3D',
    'TRectAnimation:FMX.Ani',
    'TReflectionEffect:FMX.Effects',
    'TRippleEffect:FMX.Filter.Effects',
    'TRippleTransitionEffect:FMX.Filter.Effects',
    'TRotateCrumpleTransitionEffect:FMX.Filter.Effects',
    'TRoundCube:FMX.Objects3D',
    'TSaturateTransitionEffect:FMX.Filter.Effects',
    'TSaveDialog:FMX.Dialogs',
    'TSepiaEffect:FMX.Filter.Effects',
    'TShadowEffect:FMX.Effects',
    'TShapeTransitionEffect:FMX.Filter.Effects',
    'TSharpenEffect:FMX.Filter.Effects',
    'TSlideTransitionEffect:FMX.Filter.Effects',
    'TSmoothMagnifyEffect:FMX.Filter.Effects',
    'TSolidLayer3D:FMX.Layers3D',
    'TSphere:FMX.Objects3D',
    'TSplitter3D:FMX.Layers3D',
    'TStrokeCube:FMX.Objects3D',
    'TStyleBook:FMX.Controls',
    'TSwipeTransitionEffect:FMX.Filter.Effects',
    'TSwirlEffect:FMX.Filter.Effects',
    'TSwirlTransitionEffect:FMX.Filter.Effects',
    'TText3D:FMX.Objects3D',
    'TTextLayer3D:FMX.Layers3D',
    'TTextureMaterialSource:FMX.MaterialSources',
    'TTilerEffect:FMX.Filter.Effects',
    'TTimer:FMX.Types',
    'TToonEffect:FMX.Filter.Effects',
    'TWaterTransitionEffect:FMX.Filter.Effects',
    'TWaveEffect:FMX.Filter.Effects',
    'TWaveTransitionEffect:FMX.Filter.Effects',
    'TWiggleTransitionEffect:FMX.Filter.Effects',
    'TWindowsStore:FMX.WindowsStore',
    'TWrapEffect:FMX.Filter.Effects'
  );

  // FMX �ظ����¼��������͡�������ӳ���ϵ�����������¼�����
  FMX_EVENT_DUPLICATED_CLASS_DECL_ARRAY: array[0..9] of string = (
    'OnClose:TOpenDialog|procedure (Sender: TObject);',
    'OnClose:TPageSetupDialog|procedure (Sender: TObject);',
    'OnClose:TPrintDialog|procedure (Sender: TObject);',
    'OnClose:TPrinterSetupDialog|procedure (Sender: TObject);',
    'OnClose:TSaveDialog|procedure (Sender: TObject);',
    'OnCompare:TTreeView|function (Item1: TTreeViewItem; Item2: TTreeViewItem): Integer;',
    'OnDragChange:TTreeView|procedure (SourceItem: TTreeViewItem; DestItem: TTreeViewItem; var Allow: Boolean);',
    'OnItemClick:TListBox|procedure (const Sender: TCustomListBox; const Item: TListBoxItem);', // TListBox/TColorListBox
    'OnItemClick:THeader|procedure (Item: THeaderItem);',                                                    // THeader
    'OnPaint:TPaintBox|procedure (Sender: TObject; Canvas: TCanvas);' // Only for TPaintBox
  );

  // FMX ���ظ����¼��������͡�������ӳ���ϵ�����������¼�����
  FMX_EVENT_NAME_DECL_ARRAY: array[0..159] of string = (
    'OnActionCanBegin:TAdActionCanBeginEvent|procedure (Sender: TObject; var WillLeaveApplication: Boolean);',
    'OnActionDidFinish:TNotifyEvent|procedure (Sender: TObject);',
    'OnActivate:TNotifyEvent|procedure (Sender: TObject);',
    'OnApplyStyleLookup:TNotifyEvent|procedure (Sender: TObject);',
    'OnButtonChange:TItemControlEvent|procedure (const Sender: TObject; const AItem: TListItem; const AObject: TListItemSimpleControl);',
    'OnButtonClick:TItemControlEvent|procedure (const Sender: TObject; const AItem: TListItem; const AObject: TListItemSimpleControl);',
    'OnCalcContentBounds:TOnCalcContentBoundsEvent|procedure (Sender: TObject; var ContentBounds: TRectF);',
    'OnCameraChanged:TNotifyEvent|procedure (Sender: TObject);',
    'OnCanClose:TCloseQueryEvent|procedure (Sender: TObject; var CanClose: Boolean);',
    'OnCanFocus:TCanFocusEvent|procedure (Sender: TObject; var ACanFocus: Boolean);',
    'OnCellClick:TCellClick|procedure (const Column: TColumn; const Row: Integer);',
    'OnCellDblClick:TCellClick|procedure (const Column: TColumn; const Row: Integer);',
    'OnChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnChangeCheck:TNotifyEvent|procedure (Sender: TObject);',
    'OnChanged:TNotifyEvent|procedure (Sender: TObject);',
    'OnChangeRepainted:TNotifyEvent|procedure (Sender: TObject);',
    'OnChangeTracking:TNotifyEvent|procedure (Sender: TObject);',
    'OnCheckChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnCheckChanged:TNotifyEvent|procedure (Sender: TObject);',
    'OnClick:TNotifyEvent|procedure (Sender: TObject);',
    'OnClose:TCloseEvent|procedure (Sender: TObject; var Action: TCloseAction);',
    'OnCloseQuery:TCloseQueryEvent|procedure (Sender: TObject; var CanClose: Boolean);',
    'OnClosePicker:TNotifyEvent|procedure (Sender: TObject);',
    'OnClosePopup:TNotifyEvent|procedure (Sender: TObject);',
    'OnColumnMoved:TColumnMovedEvent|procedure (Column: TColumn; FromIndex: Integer; ToIndex: Integer);',
    'OnCompare:TOnCompareListBoxItemEvent|procedure (Item1: TListBoxItem; Item2: TListBoxItem; var Result: Integer);',
    // 'OnCompare:TOnCompareTreeViewItemEvent|function (Item1: TTreeViewItem; Item2: TTreeViewItem): Integer;',
    'OnConsumeCompleted:TIAPConsumeCompletedEvent|procedure (Sender: TObject; const ProductID: string);',
    'OnConsumeFailed:TIAPConsumeFailedEvent|procedure (Sender: TObject; const ProductID: string; const ErrorMessage: string);',
    'OnCreate:TNotifyEvent|procedure (Sender: TObject);',
    'OnCreateCustomEditor:TCreateCustomEditorEvent|procedure (Sender: TObject; const Column: TColumn; var Control: TStyledControl);',
    'OnDateSelected:TNotifyEvent|procedure (Sender: TObject);',
    'OnDayClick:TNotifyEvent|procedure (Sender: TObject);',
    'OnDblClick:TNotifyEvent|procedure (Sender: TObject);',
    'OnDeactivate:TNotifyEvent|procedure (Sender: TObject);',
    'OnDeleteChangeVisible:TListViewBase.TDeleteChangeVisibilityEvent|procedure (Sender: TObject; AValue: Boolean);',
    'OnDeleteItem:TListViewBase.TDeleteItemEvent|procedure (Sender: TObject; AIndex: Integer);',
    'OnDeletingItem:TListViewBase.TDeletingItemEvent|procedure (Sender: TObject; AIndex: Integer; var ACanDelete: Boolean);',
    'OnDestroy:TNotifyEvent|procedure (Sender: TObject);',
    'OnDidFail:TAdDidFailEvent|procedure (Sender: TObject; const Error: string);',
    'OnDidFailLoadWithError:TWebBrowserDidFailLoadWithError|procedure (ASender: TObject);',
    'OnDidFinishLoad:TWebBrowserDidFinishLoad|procedure (ASender: TObject);',
    'OnDidLoad:TNotifyEvent|procedure (Sender: TObject);',
    'OnDidStartLoad:TWebBrowserDidStartLoad|procedure (ASender: TObject);',
    'OnDownloadCompleted:TIAPDownloadCompletedEvent|procedure (Sender: TObject; const ProductID: string; const ContentID: string; const FilePath: string);',
    'OnDownloadProgress:TIAPDownloadProgressEvent|procedure (Sender: TObject; const ProductID: string; const ContentID: string; TimeRemaining: Double; Progress: Single);',
    'OnDragChange:TOnListBoxDragChange|procedure (SourceItem: TListBoxItem; DestItem: TListBoxItem; var Allow: Boolean);',
    // 'OnDragChange:TOnTreeViewDragChange|procedure (SourceItem: TTreeViewItem; DestItem: TTreeViewItem; var Allow: Boolean);',
    'OnDragDrop:TDragDropEvent|procedure (Sender: TObject; const Data: TDragObject; const Point: TPointF);',
    // 'OnDragDrop:TDragDropEvent3D|procedure (Sender: TObject; const Data: TDragObject; const Point: TPoint3D);',
    'OnDragEnd:TNotifyEvent|procedure (Sender: TObject);',
    'OnDragEnter:TDragEnterEvent|procedure (Sender: TObject; const Data: TDragObject; const Point: TPointF);',
    // 'OnDragEnter:TDragEnterEvent3D|procedure (Sender: TObject; const Data: TDragObject; const Point: TPoint3D);',
    'OnDragLeave:TNotifyEvent|procedure (Sender: TObject);',
    'OnDragOver:TDragOverEvent|procedure (Sender: TObject; const Data: TDragObject; const Point: TPointF; var Operation: TDragOperation);',
    // 'OnDragOver:TDragOverEvent3D|procedure (Sender: TObject; const Data: TDragObject; const Point: TPoint3D; var Operation: TDragOperation);',
    'OnDrawColumnBackground:TDrawColumnCellEvent|procedure (Sender: TObject; const Canvas: TCanvas; const Column: TColumn; const Bounds: TRectF; const Row: Integer; const Value: TValue; const State: TGridDrawStates);',
    'OnDrawColumnCell:TDrawColumnCellEvent|procedure (Sender: TObject; const Canvas: TCanvas; const Column: TColumn; const Bounds: TRectF; const Row: Integer; const Value: TValue; const State: TGridDrawStates);',
    'OnDrawColumnHeader:TDrawColumnHeaderEvent|procedure (Sender: TObject; const Canvas: TCanvas; const Column: TColumn; const Bounds: TRectF);',
    'OnDrawEnvStamp:TPaintPageEvent|procedure (Sender: TObject; Canvas: TCanvas; PageRect: TRect; var DoneDrawing: Boolean);',
    'OnDrawFullPage:TPaintPageEvent|procedure (Sender: TObject; Canvas: TCanvas; PageRect: TRect; var DoneDrawing: Boolean);',
    'OnDrawGreekText:TPaintPageEvent|procedure (Sender: TObject; Canvas: TCanvas; PageRect: TRect; var DoneDrawing: Boolean);',
    'OnDrawItem:TDrawHeaderItemEvent|procedure (Sender: TObject; const Canvas: TCanvas; const Item: THeaderItem; const Bounds: TRectF);',
    'OnDrawMargin:TPaintPageEvent|procedure (Sender: TObject; Canvas: TCanvas; PageRect: TRect; var DoneDrawing: Boolean);',
    'OnDrawMinMargin:TPaintPageEvent|procedure (Sender: TObject; Canvas: TCanvas; PageRect: TRect; var DoneDrawing: Boolean);',
    'OnDrawRetAddress:TPaintPageEvent|procedure (Sender: TObject; Canvas: TCanvas; PageRect: TRect; var DoneDrawing: Boolean);',
    'OnDropped:TDragDropEvent|procedure (Sender: TObject; const Data: TDragObject; const Point: TPointF);',
    'OnEditingDone:TOnEditingDone|procedure (Sender: TObject; const ACol: Integer; const ARow: Integer);',
    'OnEditModeChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnEditModeChanging:TListViewBase.THandleChangeEvent|procedure (const Sender: TObject; var AHandled: Boolean);',
    'OnEnter:TNotifyEvent|procedure (Sender: TObject);',
    'OnError:TIAPErrorEvent|procedure (Sender: TObject; ErrorKind: TFailureKind; const ErrorMessage: string);',
    'OnExecute:TActionEvent|procedure (Action: TBasicAction; var Handled: Boolean);',
    'OnExit:TNotifyEvent|procedure (Sender: TObject);',
    'OnExpandedChanged:TNotifyEvent|procedure (Sender: TObject);',
    'OnExpandedChanging:TNotifyEvent|procedure (Sender: TObject);',
    'OnExternalChange:TExternalChangeEvent|procedure (ASender: TObject);',
    'OnFilter:TFilterEvent|procedure (Sender: TObject; const AFilter: string; const AValue: string; var Accept: Boolean);',
    'OnFinish:TNotifyEvent|procedure (Sender: TObject);',
    'OnFocusChanged:TNotifyEvent|procedure (Sender: TObject);',
    'OnFolderChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnGesture:TGestureEvent|procedure (Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);',
    'OnGetValue:TOnGetValue|procedure (Sender: TObject; const ACol: Integer; const ARow: Integer; var Value: TValue);',
    'OnHeaderClick:THeaderClick|procedure (Column: TColumn);',
    'OnHide:TNotifyEvent|procedure (Sender: TObject);',
    'OnHidden:TNotifyEvent|procedure (Sender: TObject);',
    'OnHint:TNotifyEvent|procedure (Sender: TObject);',
    'OnHScrollChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnItemClick:TAppearanceListView.TItemEvent|procedure (const Sender: TObject; const AItem: TListViewItem);',      // TListView
    // 'OnItemClick:TCustomListBox.TItemClickEvent|procedure (const Sender: TCustomListBox; const Item: TListBoxItem);', // TListBox/TColorListBox
    // 'OnItemClick:THeaderItemClick|procedure (Item: THeaderItem);',                                                    // THeader
    'OnItemClickEx:TListViewBase.TListItemClickEventEx|procedure (const Sender: TObject; ItemIndex: Integer; const LocalClickPos: TPointF; const ItemObject: TListItemDrawable);',
    'OnItemsChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnKeyDown:TKeyEvent|procedure (Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);',
    'OnKeyUp:TKeyEvent|procedure (Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);',
    'OnLayerMouseDown:TMouseEvent|procedure (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single);',
    'OnLayerMouseMove:TMouseMoveEvent|procedure (Sender: TObject; Shift: TShiftState; X: Single; Y: Single);',
    'OnLayerMouseUp:TMouseEvent|procedure (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single);',
    'OnLoaded:TImageLoadedEvent|procedure (Sender: TObject; const FileName: string);',
    'OnMapClick:TMapClickEvent|procedure (const Position: TMapCoordinate);',
    'OnMapDoubleClick:TMapClickEvent|procedure (const Position: TMapCoordinate);',
    'OnMapLongClick:TMapClickEvent|procedure (const Position: TMapCoordinate);',
    'OnMarkerClick:TMarkerEvent|procedure (Marker: TMapMarker);',
    'OnMarkerDoubleClick:TMarkerEvent|procedure (Marker: TMapMarker);',
    'OnMarkerDrag:TMarkerEvent|procedure (Marker: TMapMarker);',
    'OnMarkerDragEnd:TMarkerEvent|procedure (Marker: TMapMarker);',
    'OnMarkerDragStart:TMarkerEvent|procedure (Marker: TMapMarker);',
    'OnMouseDown:TMouseEvent|procedure (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single);',
    // 'OnMouseDown:TMouseEvent3D|procedure (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single; RayPos: TVector3D; RayDir: TVector3D);',
    'OnMouseEnter:TNotifyEvent|procedure (Sender: TObject);',
    'OnMouseLeave:TNotifyEvent|procedure (Sender: TObject);',
    'OnMouseMove:TMouseMoveEvent|procedure (Sender: TObject; Shift: TShiftState; X: Single; Y: Single);',
    // 'OnMouseMove:TMouseMoveEvent3D|procedure (Sender: TObject; Shift: TShiftState; X: Single; Y: Single; RayPos: TVector3D; RayDir: TVector3D);',
    'OnMouseUp:TMouseEvent|procedure (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single);',
    // 'OnMouseUp:TMouseEvent3D|procedure (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single; RayPos: TVector3D; RayDir: TVector3D);',
    'OnMouseWheel:TMouseWheelEvent|procedure (Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);',
    'OnOpenPicker:TNotifyEvent|procedure (Sender: TObject);',
    'OnPaint:TOnPaintEvent|procedure (Sender: TObject; Canvas: TCanvas; const ARect: TRectF);',
    // 'OnPaint:TPaintEvent|procedure (Sender: TObject; Canvas: TCanvas);', // Only for TPaintBox
    'OnPainting:TOnPaintEvent|procedure (Sender: TObject; Canvas: TCanvas; const ARect: TRectF);',
    'OnPermissionRequest:TPermissionRequestEvent|procedure (ASender: TObject; const AMessage: string; const AAccessGranted: Boolean);',
    'OnPopup:TNotifyEvent|procedure (Sender: TObject);',
    'OnPresentationNameChoosing:TPresenterNameChoosingEvent|procedure (Sender: TObject; var PresenterName: string);',
    'OnPresenterChanging:TOnPresenterChanging|procedure (Sender: TObject; var PresenterClass: TMultiViewPresentationClass);',
    'OnPrivacyMessage:TAnalyticsPrivacyMessageEvent|procedure (Sender: TObject; var Activate: Boolean);',
    'OnProcess:TNotifyEvent|procedure (Sender: TObject);',
    'OnProductsRequestResponse:TIAPProductsRequestResponseEvent|procedure (Sender: TObject; const Products: TIAPProductList; const InvalidProductIDs: TStrings);',
    'OnPullRefresh:TNotifyEvent|procedure (Sender: TObject);',
    'OnPurchaseCompleted:TIAPPurchaseCompletedEvent|procedure (Sender: TObject; const ProductID: string; NewTransaction: Boolean);',
    'OnRealignItem:TOnRealignItemEvent|procedure (Sender: TObject; OldIndex: Integer; NewIndex: Integer);',
    'OnRecordTransaction:TIAPRecordTransactionEvent|procedure (Sender: TObject; const ProductID: string; const TransactionID: string; TransactionDate: TDateTime);',
    'OnRender:TRenderEvent|procedure (Sender: TObject; Context: TContext3D);',
    'OnResize:TNotifyEvent|procedure (Sender: TObject);',
    'OnResized:TNotifyEvent|procedure (Sender: TObject);',
    'OnResizeItem:TOnResizeItemEvent|procedure (Sender: TObject; var NewSize: Single);',
    'OnSaveState:TNotifyEvent|procedure (Sender: TObject);',
    'OnSampleBufferReady:TSampleBufferReadyEvent|procedure (Sender: TObject; const ATime: TMediaTime);',
    'OnScrollViewChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnSearchChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnSelChanged:TNotifyEvent|procedure (Sender: TObject);',
    'OnSelectCell:TSelectCell|procedure (Sender: TObject; const ACol: Integer; const ARow: Integer; var CanSelect: Boolean);',
    'OnSelectionChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnSelectPoint:TNotifyEvent|procedure (Sender: TObject);',
    'OnSetValue:TOnSetValue|procedure (Sender: TObject; const ACol: Integer; const ARow: Integer; const Value: TValue);',
    'OnShouldStartLoadWithRequest:TWebBrowserShouldStartLoadWithRequest|procedure (ASender: TObject; const URL: string);',
    'OnShow:TNotifyEvent|procedure (Sender: TObject);',
    'OnShown:TNotifyEvent|procedure (Sender: TObject);',
    'OnStartHiding:TNotifyEvent|procedure (Sender: TObject);',
    'OnStartShowing:TNotifyEvent|procedure (Sender: TObject);',
    'OnStateChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnSwitch:TNotifyEvent|procedure (Sender: TObject);',
    'OnTap:TTapEvent|procedure (Sender: TObject; const Point: TPointF);',
    'OnTimer:TNotifyEvent|procedure (Sender: TObject);',
    'OnTouch:TTouchEvent|procedure (Sender: TObject; const Touches: TTouches; const Action: TTouchAction);',
    'OnTrack:TNotifyEvent|procedure (Sender: TObject);',
    // 'OnTrack:TOnChangeTracking|procedure (Sender: TObject; var X: Single; var Y: Single);',
    'OnTracking:TNotifyEvent|procedure (Sender: TObject);',
    'OnTypeChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnTyping:TNotifyEvent|procedure (Sender: TObject);',
    'OnUpdate:TActionEvent|procedure (Action: TBasicAction; var Handled: Boolean);',
    'OnUpdateBuffer:TNotifyEvent|procedure (Sender: TObject);',
    'OnUpdateObjects:TAppearanceListView.TItemEvent|procedure (const Sender: TObject; const AItem: TListViewItem);',
    'OnUpdatingObjects:TAppearanceListView.TUpdatingObjectsEvent|procedure (const Sender: TObject; const AItem: TListViewItem; var AHandled: Boolean);',
    'OnValidate:TValidateTextEvent|procedure (Sender: TObject; var Text: string);',
    'OnValidating:TValidateTextEvent|procedure (Sender: TObject; var Text: string);',
    'OnVerifyPayload:TIAPVerifyPayloadEvent|procedure (Sender: TObject; const Payload: string; var PayloadOk: Boolean);',
    'OnViewportPositionChange:TPositionChangeEvent|procedure (Sender: TObject; const OldViewportPosition: TPointF; const NewViewportPosition: TPointF; const ContentSizeChanged: Boolean);',
    'OnVirtualKeyboardHidden:TVirtualKeyboardEvent|procedure (Sender: TObject; KeyboardVisible: Boolean; const Bounds: TRect);',
    'OnVirtualKeyboardShown:TVirtualKeyboardEvent|procedure (Sender: TObject; KeyboardVisible: Boolean; const Bounds: TRect);',
    'OnVScrollChange:TNotifyEvent|procedure (Sender: TObject);',
    'OnWillLoad:TNotifyEvent|procedure (Sender: TObject);',
    'Painting:TPageSetupPaintingEvent|procedure (Sender: TObject; const PaperSize: SmallInt; const Orientation: TPrinterOrientation; const PageType: TPageType; var DoneDrawing: Boolean);'
  );

  // ��Щ��������Ӧ��ֵ�� VCL/FMX �в�ͬ����Ҫ������ı������ת��
  VCL_FMX_PROPERTY_ENUM_NAMES: array[0..3] of string = (
    'BorderStyle', 'FormStyle', 'Position', 'Align'
    // Color Ҫת�� Fill.Color��Font.Color Ҫת���� TextSettings.FontColor�����⴦��
  );

  // ͬ���ʵ�ö�����͵���ͬ����ӳ���ϵ�����������������
  VCL_FMX_PROPERTY_ENUM_PAIRS: array[0..219] of string = (
    'alNone:None',
    'alTop:Top',
    'alBottom:Bottom',
    'alLeft:Left',
    'alRight:Right',
    'alClient:Client',
    'alCustom:None',
    'bsNone:None',
    'bsSingle:Single',
    'bsSizeable:Sizeable',
    'bsDialog:Single',
    'bsToolWindow:ToolWindow',
    'bsSizeToolWin:SizeToolWin',
    'clSystemColor:Black',                    // Sys ��ʼ����ƥ�䣬ֻ��ȡ������ɫ������
    'clScrollBar:xFFC8C8C8',
    'clBackground:xFF763B0A',
    'clActiveCaption:xFFD1B499',
    'clInactiveCaption:xFFDBCDBF',
    'clMenu:xFFF0F0F0',
    'clWindow:xFFFFFFFF',
    'clWindowFrame:xFF646464',
    'clMenuText:Black',
    'clWindowText:Black',
    'clCaptionText:Black',
    'clActiveBorder:xFFB4B4B4',
    'clInactiveBorder:xFFFCF7F4',
    'clAppWorkSpace:xFFABABAB',
    'clHighlight:xFFFF9933',
    'clHighlightText:xFFFFFFFF',
    'clBtnFace:xFFF0F0F0',
    'clBtnShadow:xFFA0A0A0',
    'clGrayText:xFF6D6D6D',
    'clBtnText:Black',
    'clInactiveCaptionText:xFF544E43',
    'clBtnHighlight:xFFFFFFFF',
    'cl3DDkShadow:xFF696969',
    'cl3DLight:xFFE3E3E3',
    'clInfoText:Black',
    'clInfoBk:xFFE1FFFF',
    'clHotLight:xFFCC6600',
    'clGradientActiveCaption:xFFEAD1B9',
    'clGradientInactiveCaption:xFFF2E4D7',
    'clMenuHighlight:xFFFF9933',
    'clMenuBar:xFFF0F0F0',                     // Sys ����
    'clBlack:Black',
    'clMaroon:Maroon',
    'clGreen:Green',
    'clOlive:Olive',
    'clNavy:Navy',
    'clPurple:Purple',
    'clTeal:Teal',
    'clGray:Gray',
    'clSilver:Silver',
    'clRed:Red',
    'clLime:Lime',
    'clYellow:Yellow',
    'clBlue:Blue',
    'clFuchsia:Fuchsia',
    'clAqua:Aqua',
    'clLtGray:LtGray',
    'clDkGray:DkGray',
    'clWhite:White',
    'clMoneyGreen:MoneyGreen',
    'clSkyBlue:LegacySkyBlue',
    'clCream:Cream',
    'clMedGray:MedGray',
    'clNone:SysNone',
    'clDefault:SysDefault',
    'clWebSnow:Snow',
    'clWebFloralWhite:FloralWhite',
    'clWebLavenderBlush:LavenderBlush',
    'clWebOldLace:OldLace',
    'clWebIvory:Ivory',
    'clWebCornSilk:CornSilk',
    'clWebBeige:Beige',
    'clWebAntiqueWhite:AntiqueWhite',
    'clWebWheat:Wheat',
    'clWebAliceBlue:AliceBlue',
    'clWebGhostWhite:GhostWhite',
    'clWebLavender:Lavender',
    'clWebSeashell:Seashell',
    'clWebLightYellow:LightYellow',
    'clWebPapayaWhip:PapayaWhip',
    'clWebNavajoWhite:NavajoWhite',
    'clWebMoccasin:Moccasin',
    'clWebBurlywood:Burlywood',
    'clWebAzure:Azure',
    'clWebMintcream:Mintcream',
    'clWebHoneydew:Honeydew',
    'clWebLinen:Linen',
    'clWebLemonChiffon:LemonChiffon',
    'clWebBlanchedAlmond:BlanchedAlmond',
    'clWebBisque:Bisque',
    'clWebPeachPuff:PeachPuff',
    'clWebTan:Tan',
    'clWebYellow:Yellow',
    'clWebDarkOrange:DarkOrange',
    'clWebRed:Red',
    'clWebDarkRed:DarkRed',
    'clWebMaroon:Maroon',
    'clWebIndianRed:IndianRed',
    'clWebSalmon:Salmon',
    'clWebCoral:Coral',
    'clWebGold:Gold',
    'clWebTomato:Tomato',
    'clWebCrimson:Crimson',
    'clWebBrown:Brown',
    'clWebChocolate:Chocolate',
    'clWebSandyBrown:SandyBrown',
    'clWebLightSalmon:LightSalmon',
    'clWebLightCoral:LightCoral',
    'clWebOrange:Orange',
    'clWebOrangeRed:OrangeRed',
    'clWebFirebrick:Firebrick',
    'clWebSaddleBrown:SaddleBrown',
    'clWebSienna:Sienna',
    'clWebPeru:Peru',
    'clWebDarkSalmon:DarkSalmon',
    'clWebRosyBrown:RosyBrown',
    'clWebPaleGoldenrod:PaleGoldenrod',
    'clWebLightGoldenrodYellow:LightGoldenrodYellow',
    'clWebOlive:Olive',
    'clWebForestGreen:ForestGreen',
    'clWebGreenYellow:GreenYellow',
    'clWebChartreuse:Chartreuse',
    'clWebLightGreen:LightGreen',
    'clWebAquamarine:Aquamarine',
    'clWebSeaGreen:SeaGreen',
    'clWebGoldenRod:GoldenRod',
    'clWebKhaki:Khaki',
    'clWebOliveDrab:OliveDrab',
    'clWebGreen:Green',
    'clWebYellowGreen:YellowGreen',
    'clWebLawnGreen:LawnGreen',
    'clWebPaleGreen:PaleGreen',
    'clWebMediumAquamarine:MediumAquamarine',
    'clWebMediumSeaGreen:MediumSeaGreen',
    'clWebDarkGoldenRod:DarkGoldenRod',
    'clWebDarkKhaki:DarkKhaki',
    'clWebDarkOliveGreen:DarkOliveGreen',
    'clWebDarkgreen:Darkgreen',
    'clWebLimeGreen:LimeGreen',
    'clWebLime:Lime',
    'clWebSpringGreen:SpringGreen',
    'clWebMediumSpringGreen:MediumSpringGreen',
    'clWebDarkSeaGreen:DarkSeaGreen',
    'clWebLightSeaGreen:LightSeaGreen',
    'clWebPaleTurquoise:PaleTurquoise',
    'clWebLightCyan:LightCyan',
    'clWebLightBlue:LightBlue',
    'clWebLightSkyBlue:LightSkyBlue',
    'clWebCornFlowerBlue:CornFlowerBlue',
    'clWebDarkBlue:DarkBlue',
    'clWebIndigo:Indigo',
    'clWebMediumTurquoise:MediumTurquoise',
    'clWebTurquoise:Turquoise',
    'clWebCyan:Cyan',
    'clWebAqua:Aqua',
    'clWebPowderBlue:PowderBlue',
    'clWebSkyBlue:SkyBlue',
    'clWebRoyalBlue:RoyalBlue',
    'clWebMediumBlue:MediumBlue',
    'clWebMidnightBlue:MidnightBlue',
    'clWebDarkTurquoise:DarkTurquoise',
    'clWebCadetBlue:CadetBlue',
    'clWebDarkCyan:DarkCyan',
    'clWebTeal:Teal',
    'clWebDeepskyBlue:DeepskyBlue',
    'clWebDodgerBlue:DodgerBlue',
    'clWebBlue:Blue',
    'clWebNavy:Navy',
    'clWebDarkViolet:DarkViolet',
    'clWebDarkOrchid:DarkOrchid',
    'clWebMagenta:Magenta',
    'clWebFuchsia:Fuchsia',
    'clWebDarkMagenta:DarkMagenta',
    'clWebMediumVioletRed:MediumVioletRed',
    'clWebPaleVioletRed:PaleVioletRed',
    'clWebBlueViolet:BlueViolet',
    'clWebMediumOrchid:MediumOrchid',
    'clWebMediumPurple:MediumPurple',
    'clWebPurple:Purple',
    'clWebDeepPink:DeepPink',
    'clWebLightPink:LightPink',
    'clWebViolet:Violet',
    'clWebOrchid:Orchid',
    'clWebPlum:Plum',
    'clWebThistle:Thistle',
    'clWebHotPink:HotPink',
    'clWebPink:Pink',
    'clWebLightSteelBlue:LightSteelBlue',
    'clWebMediumSlateBlue:MediumSlateBlue',
    'clWebLightSlateGray:LightSlateGray',
    'clWebWhite:White',
    'clWebLightgrey:Lightgrey',
    'clWebGray:Gray',
    'clWebSteelBlue:SteelBlue',
    'clWebSlateBlue:SlateBlue',
    'clWebSlateGray:SlateGray',
    'clWebWhiteSmoke:WhiteSmoke',
    'clWebSilver:Silver',
    'clWebDimGray:DimGray',
    'clWebMistyRose:MistyRose',
    'clWebDarkSlateBlue:DarkSlateBlue',
    'clWebDarkSlategray:DarkSlategray',
    'clWebGainsboro:Gainsboro',
    'clWebDarkGray:DarkGray',
    'clWebBlack:Black',
    'fsNormal:Normal',
    'fsMDIForm:Normal',
    'fsMDIChild:Normal',
    'fsStayOnTop:StayOnTop',
    'poDesigned:Designed',
    'poDefault:Default',
    'poDefaultPosOnly:DefaultPosOnly',
    'poDefaultSizeOnly:DefaultSizeOnly',
    'poScreenCenter:ScreenCenter',
    'poDesktopCenter:DesktopCenter',
    'poMainFormCenter:MainFormCenter',
    'poOwnerFormCenter:OwnerFormCenter'
  );

  // �����ͬ��������ת����Ӧ��ϵ�����ܲ�ͬ��
  VCL_FMX_CONTAINER_PROPNAMES_PAIRS: array[0..17] of string = (
    'Action',
    'ActiveControl',
    'BorderIcons',
    'Caption',
    'ClientHeight',
    'ClientWidth',
    'Cursor',
    'Height',
    'Left',
    'Padding',
    'ShowHint',
    'Tag',
    'Top',
    'Touch',
    'TransparentColor:Transparency',
    'Visible',
    'Width',
    'WindowState'
  );

function CnGetFmxClassFromVclClass(const ComponentClass: string): string;
begin
  if not FVclFmxClassMap.TryGetValue(ComponentClass, Result) then
    Result := '';
end;

function CnIsVclEnumPropertyNeedConvert(const PropertyName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(VCL_FMX_PROPERTY_ENUM_NAMES) to High(VCL_FMX_PROPERTY_ENUM_NAMES) do
  begin
    if VCL_FMX_PROPERTY_ENUM_NAMES[I] = PropertyName then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function CnConvertEnumValue(const PropertyValue: string): string;
begin
  if not FVclFmxEnumMap.TryGetValue(PropertyValue, Result) then
    Result := PropertyValue;
end;

procedure LoadFmxClassUnitMap;
var
  I, P: Integer;
begin
  FFmxClassUnitMap := TDictionary<string, string>.Create;
  for I := Low(FMX_CLASS_UNIT_PAIRS) to High(FMX_CLASS_UNIT_PAIRS) do
  begin
    P := Pos(':', FMX_CLASS_UNIT_PAIRS[I]);
    if P > 1 then
    begin
      FFmxClassUnitMap.Add(Copy(FMX_CLASS_UNIT_PAIRS[I], 1, P - 1),
        Copy(FMX_CLASS_UNIT_PAIRS[I], P + 1, MaxInt));
    end;
  end;
end;

procedure LoadFmxEventUnitMap;
var
  I, P: Integer;
begin
  FFmxEventDeclMap := TDictionary<string, string>.Create;
  for I := Low(FMX_EVENT_NAME_DECL_ARRAY) to High(FMX_EVENT_NAME_DECL_ARRAY) do
  begin
    P := Pos(':', FMX_EVENT_NAME_DECL_ARRAY[I]);
    if P > 1 then
      FFmxEventDeclMap.Add(Copy(FMX_EVENT_NAME_DECL_ARRAY[I], 1, P - 1),
        Copy(FMX_EVENT_NAME_DECL_ARRAY[I], P + 1, MaxInt));
  end;
end;

procedure LoadVclFmxClassMap;
var
  I, P: Integer;
begin
  FVclFmxClassMap := TDictionary<string, string>.Create;
  for I := Low(VCL_FMX_CLASS_PAIRS) to High(VCL_FMX_CLASS_PAIRS) do
  begin
    P := Pos(':', VCL_FMX_CLASS_PAIRS[I]);
    if P > 1 then
    begin
      FVclFmxClassMap.Add(Copy(VCL_FMX_CLASS_PAIRS[I], 1, P - 1),
        Copy(VCL_FMX_CLASS_PAIRS[I], P + 1, MaxInt));
    end;
  end;
end;

procedure LoadVclFmxEnumMap;
var
  I, P: Integer;
begin
  FVclFmxEnumMap := TDictionary<string, string>.Create;
  for I := Low(VCL_FMX_PROPERTY_ENUM_PAIRS) to High(VCL_FMX_PROPERTY_ENUM_PAIRS) do
  begin
    P := Pos(':', VCL_FMX_PROPERTY_ENUM_PAIRS[I]);
    if P > 1 then
    begin
      FVclFmxEnumMap.Add(Copy(VCL_FMX_PROPERTY_ENUM_PAIRS[I], 1, P - 1),
        Copy(VCL_FMX_PROPERTY_ENUM_PAIRS[I], P + 1, MaxInt));
    end;
  end;
end;

procedure LoadVclFmxPropNameMap;
var
  I, P: Integer;
begin
  FVclFmxPropNameMap := TDictionary<string, string>.Create;
  for I := Low(VCL_FMX_CONTAINER_PROPNAMES_PAIRS) to High(VCL_FMX_CONTAINER_PROPNAMES_PAIRS) do
  begin
    P := Pos(':', VCL_FMX_CONTAINER_PROPNAMES_PAIRS[I]);
    if P > 1 then
    begin
      FVclFmxPropNameMap.Add(Copy(VCL_FMX_CONTAINER_PROPNAMES_PAIRS[I], 1, P - 1),
        Copy(VCL_FMX_CONTAINER_PROPNAMES_PAIRS[I], P + 1, MaxInt));
    end
    else
      FVclFmxPropNameMap.Add(VCL_FMX_CONTAINER_PROPNAMES_PAIRS[I], VCL_FMX_CONTAINER_PROPNAMES_PAIRS[I]);
  end;
end;

procedure CheckInitPropertyConverterMap;
var
  List: TStrings;
  Converter: TCnPropertyConverterClass;
  S: string;
begin
  if FVclPropertyConverterMap = nil then
  begin
    FVclPropertyConverterMap := TDictionary<string, TCnPropertyConverterClass>.Create();
    List := TStringList.Create;
    for Converter in FConverterClasses do
    begin
      List.Clear;
      Converter.GetProperties(List);
      for S in List do
        FVclPropertyConverterMap.AddOrSetValue(S, Converter);
    end;
  end;
end;

function FindEventDecl(const EventName, ComponentClass: string): string;
var
  I, P: Integer;
  S: string;
begin
  Result := '';
  S := EventName + ':' + ComponentClass;
  for I := Low(FMX_EVENT_DUPLICATED_CLASS_DECL_ARRAY) to
    High(FMX_EVENT_DUPLICATED_CLASS_DECL_ARRAY) do
  begin
    if Pos(S, FMX_EVENT_DUPLICATED_CLASS_DECL_ARRAY[I]) = 1 then
    begin
      P := Pos('|', FMX_EVENT_DUPLICATED_CLASS_DECL_ARRAY[I]);
      if P > 1 then
      begin
        Result := Copy(FMX_EVENT_DUPLICATED_CLASS_DECL_ARRAY[I], P + 1, MaxInt);
        Exit;
      end;
    end;
  end;

  FFmxEventDeclMap.TryGetValue(EventName, Result);
end;

function GetFloatStringFromInteger(IntValue: Integer): string;
begin
  Result := IntToStr(IntValue) + '.000000000000000000';
end;

function CnConvertPropertiesFromVclToFmx(const InComponentClass, InContainerClass: string;
  var OutComponentClass: string; InProperties, OutProperties, OutEventsIntf,
  OutEventsImpl: TStrings; IsContainer: Boolean; Tab: Integer): Boolean;
var
  P: Integer;
  Converter: TCnPropertyConverterClass;
  S, PropName, PropValue, Decl: string;

  function IsPropNameEvent(const AProp: string): Boolean;
  begin
    Result := False;
    if Length(AProp) >= 3 then
    begin
      if (AProp[1] = 'O') and (AProp[2] = 'n') and (AProp[3] in ['A'..'Z']) then
        Result := True;
    end;
  end;

  procedure WriteOriginProp;
  begin
    if OutProperties <> nil then
      OutProperties.Add(Format('%s = %s', [PropName, PropValue]));
  end;

  function ContainsHead(const Head: string; List: TStrings): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := 0 to List.Count - 1 do
    begin
      if Pos(Head, List[I]) = 1 then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;

begin
  Result := False;
  CheckInitPropertyConverterMap;
  OutComponentClass := CnGetFmxClassFromVclClass(InComponentClass);

  // ����������޶�Ӧ������˳�
  if (InComponentClass <> InContainerClass) and (OutComponentClass = '') then
    Exit;

  if OutProperties <> nil then
    OutProperties.Clear;

  // ��ǰ���⴦������ TMemo û�� WordWrap ���ԣ�Ĭ��Ϊ True��������Ҫд
  // TextSettings.WordWrap Ϊ True �� FMX �У�Ĭ��Ϊ False��
  if InComponentClass = 'TMemo' then
  begin
    if not ContainsHead('WordWrap', InProperties) then
      OutProperties.Add('TextSettings.WordWrap = True');
  end;

  while InProperties.Count > 0 do
  begin
    S := InProperties[0];
    P := Pos(' = ', S);
    if P <= 0 then
    begin
      InProperties.Delete(0);
      Continue;
    end;

    PropName := Trim(Copy(S, 1, P - 1));
    PropValue := Trim(Copy(S, P + 3, MaxInt));

    // TODO: ���� PropName �� InComponentClass �ж��Ƿ��¼�
    // ���������ñȽ����Ĺ���ǰ���ַ��� On ���ҵ�������ĸ�Ǵ�д
    if IsPropNameEvent(PropName) then
    begin
      // �ٴ��� Event ��
      WriteOriginProp;  // OutProperties ��ԭ�ⲻ��д���¼�����

      if (OutEventsIntf <> nil) and (OutEventsImpl <> nil) then
      begin
        // ����������д�����õ�����
        Decl := FindEventDecl(PropName, InComponentClass);
        P := Pos('|', Decl);
        if P > 1 then
          Decl := Copy(Decl, P + 1, MaxInt);
        P := Pos(' (', Decl);
        if P > 1 then
        begin
          Decl := Copy(Decl, 1, P) + '%s' + Copy(Decl, P + 1, MaxInt);
          S := '    ' + Format(Decl, [PropValue]);
          if OutEventsIntf.IndexOf(S) < 0 then // ���ܶ���¼�ָ��ͬһ��ʵ�֣�Ҫ����
          begin
            OutEventsImpl.Add(Format(Decl, [InContainerClass + '.' + PropValue]));
            OutEventsImpl.Add('begin');
            OutEventsImpl.Add('  // To Implement.');
            OutEventsImpl.Add('end;');
            OutEventsImpl.Add('');
            OutEventsIntf.Add(S);
          end;
        end;
      end;
    end
    else if IsContainer then
    begin
      Converter := TCnContainerConverter;
      Converter.ProcessProperties(PropName, InComponentClass, PropValue,
        InProperties, OutProperties);
    end
    else  // TODO: ���� InProperties ���ÿ�������¼������ԣ��� Converter ����
    begin
      // ��������ȫƥ���ת����
      if FVclPropertyConverterMap.TryGetValue(PropName, Converter) then
        Converter.ProcessProperties(PropName, InComponentClass, PropValue,
        InProperties, OutProperties)
      else
      begin
        P := Pos('.', PropName); // ��������ԣ����Ƿ���ƥ���ǰ��ת����
        if P > 1 then
        begin
          S := Copy(PropName, 1, P );
          if FVclPropertyConverterMap.TryGetValue(S, Converter) then
            Converter.ProcessProperties(S, InComponentClass, PropValue,
            InProperties, OutProperties);
        end; // ��ƥ������Բ�д����ò���ʶ
      end;
    end;
    InProperties.Delete(0);
  end;
  Result := True;
end;

function CnGetFmxUnitNameFromClass(const ComponentClass: string): string;
begin
  if not FFmxClassUnitMap.TryGetValue(ComponentClass, Result) then
    Result := '';
end;

{ TCnPropertyConverter }

class procedure TCnPropertyConverter.GetProperties(OutProperties: TStrings);
begin

end;

class procedure TCnPropertyConverter.ProcessProperties(const PropertyName,
  TheClassName, PropertyValue: string; InProperties, OutProperties: TStrings;
  Tab: Integer);
begin

end;

procedure RegisterCnPropertyConverter(AClass: TCnPropertyConverterClass);
begin
  if AClass <> nil then
    FConverterClasses.Add(AClass);
end;

{ TCnContainerConverter }

class procedure TCnContainerConverter.GetProperties(OutProperties: TStrings);
begin
  // ɶ������Ҳû��
end;

class procedure TCnContainerConverter.ProcessProperties(const PropertyName,
  TheClassName, PropertyValue: string; InProperties, OutProperties: TStrings;
  Tab: Integer);
var
  NewStr: string;
begin
  if FVclFmxPropNameMap.TryGetValue(PropertyName, NewStr) then    // ����������ͬ����ͬ������ת����
    OutProperties.Add(Format('%s = %s', [NewStr, PropertyValue]))
  else if CnIsVclEnumPropertyNeedConvert(PropertyName) then
  begin
    // ��������ͬ���ǲ�ͬ���͵�ö����һһ��Ӧ��
    if FVclFmxEnumMap.TryGetValue(PropertyValue, NewStr) then
      OutProperties.Add(Format('%s = %s', [PropertyName, NewStr]))
    else
      OutProperties.Add(Format('%s = %s', [PropertyName, PropertyValue]));
  end
  else if (PropertyName = 'Padding.Bottom') or (PropertyName = 'Padding.Left') or
    (PropertyName = 'Padding.Right') or (PropertyName = 'Padding.Top') then
  begin
    OutProperties.Add(Format('%s = %s', [PropertyName,
      GetFloatStringFromInteger(StrToIntDef(PropertyValue, 0))]));
  end
  else if PropertyName = 'Color' then
  begin
    if FVclFmxEnumMap.TryGetValue(PropertyValue, NewStr) then
      OutProperties.Add(Format('%s = %s', ['Fill.Color', NewStr]))
    else
      OutProperties.Add(Format('%s = %s', ['Fill.Color', PropertyValue]));

    OutProperties.Add('Fill.Kind = Solid');
  end
  else if Pos('Touch.', PropertyName) = 1 then
  begin
    // Touch ������ֵȫ��д��
    OutProperties.Add(Format('%s = %s', [PropertyName, PropertyValue]));
  end;
end;

initialization
  LoadFmxClassUnitMap;
  LoadFmxEventUnitMap;
  LoadVclFmxClassMap;
  LoadVclFmxPropNameMap;
  LoadVclFmxEnumMap;

  FConverterClasses := TList<TCnPropertyConverterClass>.Create;

finalization
  FConverterClasses.Free;

  FVclFmxEnumMap.Free;
  FVclFmxPropNameMap.Free;
  FVclFmxClassMap.Free;
  FFmxClassUnitMap.Free;
  FFmxEventDeclMap.Free;

end.