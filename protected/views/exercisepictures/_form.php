<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'exercise_pictures-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('exercisepictures/create') : $this->createUrl('exercisepictures/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'label'); ?>
	<?php echo $form->textField($model,'label',array('size'=>60)); ?>
	<?php echo $form->error($model,'label'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'picture'); ?>
<?php $this->widget('application.extensions.elfinder.FilePicker',array(
	'model'=>$model,
	'attribute'=>'picture',
)); ?>	<?php echo $form->error($model,'picture'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'description'); ?>
	<?php $this->widget('application.extensions.elrtef.elRTE', array(
		'model' => $model,		'attribute' => 'description',
		'options' => array(
			'cssClass' => 'el-rte',
			'absoluteURLs'=>true,
			'allowSource' => true,
			'styleWithCss'=>'',
			'height' => 400,
			'fmAllow'=>true,
			'fmOpen'=>'js:function(callback) {$("<div id=\"elfinder\" />").elfinder(%elfopts%);}',
			'toolbar' => 'maxi',
		),
		'elfoptions' => array(
			'url'=>'auto',
			'passkey'=>'t1fq4mstun8oq6hh606hn28fld',
			'dialog'=>array('width'=>'900','modal'=>true,'title'=>'Media Manager'),			'closeOnEditorCallback'=>true,
			'editorCallback'=>'js:callback'
		),
	));?>
	<?php echo $form->error($model,'description'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'language_id'); ?>
	<?php echo $form->dropDownList($model,'language_id', Language::getDropdownList()); ?>
	<?php echo $form->error($model,'language_id'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'published'); ?>
	<?php echo $form->checkBox($model,'published'); ?>
	<?php echo $form->error($model,'published'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'sort'); ?>
	<?php echo $form->textField($model,'sort',array('size'=>60)); ?>
	<?php echo $form->error($model,'sort'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'exercise_id'); ?>
	<?php echo $form->dropDownList($model,'exercise_id', Exercise::getDropdownList()); ?>
	<?php echo $form->error($model,'exercise_id'); ?></div>
		
	

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('exercisepictures/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->