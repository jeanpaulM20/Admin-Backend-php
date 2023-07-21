<div class="form">

	<?php
	$form = $this->beginWidget('CActiveForm', array(
		'id'					 => 'goal-form',
		'enableAjaxValidation'	 => false,
		'action'				 => $model->isNewRecord ? $this->createUrl('goal/create') : $this->createUrl('goal/update', array('id'			 => $model->id)),
		'htmlOptions'	 => array('enctype' => 'multipart/form-data'),
			));
	?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

		<?php echo $form->errorSummary($model); ?>

	<div class="row">
		<?php echo $form->labelEx($model, 'target'); ?>
		<?php echo $form->textField($model, 'target', array('size' => 60)); ?>
		<?php echo $form->error($model, 'target'); ?></div>
	<div class="row">
		<?php echo $form->labelEx($model, 'description'); ?>
		<?php echo $form->textArea($model, 'description', array('size' => 60)); ?>
		<?php echo $form->error($model, 'description'); ?></div>
	<div class="row">
		<?php echo $form->labelEx($model, 'duration_total'); ?>
		<?php echo Helper::formatDuration($model->duration_total); ?>
		<?php echo $form->error($model, 'duration_total'); ?></div>
	<div class="row">
		<?php echo $form->labelEx($model, 'achieved'); ?>
		<?php echo $form->checkBox($model, 'achieved'); ?>
		<?php echo $form->error($model, 'achieved'); ?></div>
	<div class="row">
		<?php echo $form->labelEx($model, 'client_id'); ?>
		<?php echo $form->dropDownList($model, 'client_id', Client::getDropdownList(), array('id' => 'client_select')); ?>
		<?php echo $form->error($model, 'client_id'); ?></div>
	<div class="row">
		<?php echo $form->labelEx($model, 'trainings'); ?>
		<?php echo CHtml::activeDropDownList($model, 'trainings', Training::getDropdownListByClientId($model->client_id), array('multiple'	 => true, 'class'		 => 'chzn-select', 'style'		 => 'width:380px;', 'id' => 'training-select')) ?>
		<?php echo $form->error($model, 'trainings'); ?>
	</div>	


	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
		echo CHtml::htmlButton('Cancel', array(
			'onclick' => 'window.location="' . $this->createUrl('goal/admin') . '";'
		));
		?>
	</div>

<?php $this->endWidget(); ?>
<?php $this->widget('ext.EChosen.EChosen'); ?>	
</div><!-- form -->
<script type="text/javascript">
	$(document).ready(function(){
		$('#client_select').change(function(){
			$.ajax({
				url: "<?php echo $this->createUrl('training/byClient')?>/" + $(this).val(),
				context: $('#training-select')
			}).done(function(data) {
				$('#training-select_chzn').remove();
				var el = $(this);
				var newOptions = jQuery.parseJSON(data);
				el.empty();
				$.each(newOptions, function(key, value) {
					el.append($("<option></option>")
					   .attr("value", key).text(value));
				});
				el.removeClass('chzn-done');
				el.chosen([]);
			});
		});
	});
</script>