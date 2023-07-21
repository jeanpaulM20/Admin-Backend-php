<?php
$this->breadcrumbs=array(
	'Screen stats'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Screen statistics</h1>

<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'screenstats-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('screenstats-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		array(
			'name' => 'date',
			'class'=>'application.extensions.datecolumn.SYDateColumn',
		),
		array(
			'name' => 'locker_search',
			'value'=>'$data->locker ? $data->locker->getModelDisplay() : ""',
		),
		'screen',
		'time',
		'visits',
		'clicks',
		'subclicks',
	),
)); ?>
