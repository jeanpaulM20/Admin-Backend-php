<?php
Yii::import('zii.widgets.jui.CJuiInputWidget');

class FilePicker extends CJuiInputWidget
{
	
	public $buttonLabel = 'Select file...';
	public $storage = 'filesystem';
	
	/**
	 * Run this widget.
	 * This method registers necessary javascript and renders the needed HTML code.
	 */
	public function run()
	{
		$path = pathinfo(__FILE__); 
		$basePath = $path['dirname']. '/assets';		
		$baseUrl=Yii::app()->getAssetManager()->publish($basePath);
		
		$cs=Yii::app()->getClientScript();
		$cs->registerCoreScript('jquery');
		$cs->registerCoreScript('jquery.ui');
		
		$cs->registerCssFile($baseUrl.'/css/elfinder.min.css');
		$cs->registerCssFile($baseUrl.'/css/theme.css');
		
		$cs->registerScriptFile($baseUrl.'/js/elfinder.min.js', CClientScript::POS_END);
		
		list($name,$id)=$this->resolveNameID();

		if(isset($this->htmlOptions['id']))
			$id=$this->htmlOptions['id'];
		else
			$this->htmlOptions['id']=$id;
		if(isset($this->htmlOptions['name']))
			$name=$this->htmlOptions['name'];
		else
			$this->htmlOptions['name']=$name;
		
		if($this->hasModel())
			echo CHtml::activeTextField($this->model,$this->attribute,$this->htmlOptions);
		else
			echo CHtml::textField($name,$this->value,$this->htmlOptions);
		
		echo CHtml::button($this->buttonLabel, array(
			'onclick' => 'showFileDialog("' . $id . '", "' . $this->storage . '")'
		));
		
		$options=CJavaScript::encode($this->options);
		
		
		$js = "
			function showFileDialog(id, storage) {
				var fm = $('<div/>').dialogelfinder({
					url : '" . Yii::app()->getBaseUrl() . "/elfinder/' + storage,
					lang : 'en',
					width : 840,
					destroyOnClose : true,
					getFileCallback : function(files, fm) {
						$('#' + id).val(files.url);
					},
					commandsOptions : {
						getfile : {
							oncomplete : 'close',
							folders : false
						}
					}
				}).dialogelfinder('instance');
			}
		";
		
		
		Yii::app()->getClientScript()->registerScript(__CLASS__, $js, CClientScript::POS_END);
	}
}