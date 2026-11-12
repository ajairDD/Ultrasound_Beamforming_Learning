param(
  [string]$Root = 'D:\Ultrasound_Beamforming_Learning',
  [string]$Output = 'work\pdfs\figure_ocr.json',
  [string]$Chapter = ''
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null=[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
$null=[Windows.Graphics.Imaging.BitmapDecoder,Windows.Foundation,ContentType=WindowsRuntime]
$null=[Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
$null=[Windows.Globalization.Language,Windows.Foundation,ContentType=WindowsRuntime]
$asTask=([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
  $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1)
function Await-Operation($Operation,[Type]$Type) {
  $task=$asTask.MakeGenericMethod($Type).Invoke($null,@($Operation))
  $task.Wait()
  $task.Result
}
$language=New-Object Windows.Globalization.Language 'zh-Hans-CN'
$engine=[Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
if(-not $engine){throw 'Chinese Windows OCR is not available.'}
$files=@(Get-ChildItem -LiteralPath (Join-Path $Root 'chapters') -Filter '*.png' -Recurse |
  Where-Object { -not $Chapter -or $_.FullName.Contains($Chapter) })
$records=@()
foreach($file in $files){
  $storage=Await-Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($file.FullName)) ([Windows.Storage.StorageFile])
  $stream=Await-Operation ($storage.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  try{
    $decoder=Await-Operation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $transform=New-Object Windows.Graphics.Imaging.BitmapTransform
    $ratio=[Math]::Min(1.0,2300.0/[Math]::Max($decoder.PixelWidth,$decoder.PixelHeight))
    $transform.ScaledWidth=[uint32]([Math]::Round($decoder.PixelWidth*$ratio))
    $transform.ScaledHeight=[uint32]([Math]::Round($decoder.PixelHeight*$ratio))
    $operation=$decoder.GetSoftwareBitmapAsync([Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8,
      [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied,$transform,
      [Windows.Graphics.Imaging.ExifOrientationMode]::IgnoreExifOrientation,
      [Windows.Graphics.Imaging.ColorManagementMode]::DoNotColorManage)
    $bitmap=Await-Operation $operation ([Windows.Graphics.Imaging.SoftwareBitmap])
    try{
      $result=Await-Operation ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
      $records+=@{file=$file.FullName.Substring($Root.Length+1).Replace('\','/');text=$result.Text}
    }finally{$bitmap.Dispose()}
  }finally{$stream.Dispose()}
  Write-Output "OCR $($records.Count)/$($files.Count): $($file.Name)"
}
$json=ConvertTo-Json -InputObject @($records) -Depth 5
[IO.File]::WriteAllText((Join-Path $Root $Output),$json,[Text.UTF8Encoding]::new($false))
Write-Output "Saved OCR for $($records.Count) figures."
