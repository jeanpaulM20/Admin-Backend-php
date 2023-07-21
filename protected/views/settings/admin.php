<h1>Settings</h1>
 
<div class="form">
	<?php echo CHtml::beginForm(); ?>
	
	<?php foreach ($items as $key => $value): ?>
	<div class="row">
		<?php echo CHtml::label($this->getLabel($key), $key) ?>
		<?php echo CHtml::textField($key, $value) ?>
	</div>
	<?php endforeach; ?>
	
	<div class="row submit">
        <?php echo CHtml::submitButton('Save', array('name' => '')); ?>
    </div>
	<?php echo CHtml::endForm(); ?>
</div>